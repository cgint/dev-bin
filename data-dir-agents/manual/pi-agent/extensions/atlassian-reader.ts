import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

type LogLevel = "INFO" | "ERROR";

async function convertToMarkdown(html: string): Promise<string> {
	// Try to locate url2md.py in typical paths or assume in PATH
	let cmd = "url2md.py";
	const possiblePaths = [
		path.join(os.homedir(), ".local/bin/url2md.py"),
		"/usr/local/bin/url2md.py"
	];
	
	for (const p of possiblePaths) {
		if (fs.existsSync(p)) {
			cmd = p;
			break;
		}
	}

	// Create temp file for HTML content
	const tempDir = os.tmpdir();
	const tempFile = path.join(tempDir, `confluence-page-${Date.now()}.html`);
	
	try {
		await fs.promises.writeFile(tempFile, html, "utf8");
		// Run url2md.py with GFM format
		// Since it has a shebang and +x, execute directly to respect uv/env
		const command = `"${cmd}" "${tempFile}" --to-format gfm`;
			
		const { stdout } = await execAsync(command);
		return stdout;
	} catch (e: any) {
		// Fallback: Return raw HTML if conversion fails, but log it
		console.error("Markdown conversion failed:", e);
		return `[Markdown conversion failed: ${e.message}]\n\n${html}`;
	} finally {
		// Cleanup
		if (fs.existsSync(tempFile)) {
			await fs.promises.unlink(tempFile).catch(() => {});
		}
	}
}

function log(ctx: any, level: LogLevel, message: string, data?: unknown) {
	// Prefer a non-intrusive log surface.
	// - notify: short
	// - setStatus: persistent
	// We'll only notify on errors; otherwise keep it quiet.
	if (level === "ERROR") {
		ctx.ui.notify(message, "error");
		if (data) ctx.ui.notify(typeof data === "string" ? data : JSON.stringify(data), "error");
	}
}

function requireEnv() {
	const email = process.env.ATTL_EMAIL;
	const apiToken = process.env.ATTL_KEY;
	if (!email) throw new Error("ATTL_EMAIL environment variable is required");
	if (!apiToken) throw new Error("ATTL_KEY environment variable is required");
	return { email, apiToken };
}

function basicAuthHeader(email: string, apiToken: string) {
	const token = Buffer.from(`${email}:${apiToken}`, "utf8").toString("base64");
	return `Basic ${token}`;
}

async function fetchJson(url: string, init: RequestInit, signal?: AbortSignal): Promise<any> {
	const res = await fetch(url, { ...init, signal });
	const text = await res.text();
	let data: any = null;
	try {
		data = text ? JSON.parse(text) : null;
	} catch {
		data = text;
	}
	if (!res.ok) {
		throw new Error(`HTTP ${res.status} ${res.statusText}: ${typeof data === "string" ? data : JSON.stringify(data)}`);
	}
	return data;
}

function newSessionId() {
	const timePart = new Date().toISOString().slice(0, 19).replace(/[T:]/g, "-");
	return `atlassian-session-${timePart}`;
}

async function atlassianChatImpl(
	query: string,
	sessionId: string | undefined,
	modelCategory: string | undefined,
	signal: AbortSignal | undefined
) {
	const { email, apiToken } = requireEnv();
	const sid = sessionId ?? newSessionId();
	const cat = modelCategory ?? "medium";

	const baseUrl = "https://jira-confluence.prod.devsupport.smec.services";
	const url = `${baseUrl}/chat/react`;

	const body = {
		query,
		allowed_tools: [
			"confluence_term_search_tool",
			"jira_story_by_id_tool",
			"jira_term_search_tool",
			"confluence_page_by_id_tool",
			"confluence_child_pages_tool",
			"jira_stories_by_ids_tool",
			"confluence_pages_by_ids_tool",
		],
		session_id: sid,
		model_category: cat,
	};

	const data = await fetchJson(
		url,
		{
			method: "POST",
			headers: {
				"content-type": "application/json",
				"atlassian-email": email,
				"atlassian-token": apiToken,
			},
			body: JSON.stringify(body),
		},
		signal
	);

	const answer = data?.answer ?? "No answer received from Atlassian API";
	const returnedSessionId = data?.session_id ?? sid;

	return { answer: String(answer), sessionId: String(returnedSessionId), raw: data };
}

async function fetchConfluencePageImpl(pageId: string, expand: string | undefined, format: string | undefined, includeChildren: boolean | undefined, signal: AbortSignal | undefined) {
	const { email, apiToken } = requireEnv();
	const baseUrl = "https://smec.atlassian.net";
	const exp = expand ?? "body.export_view,space";

	const url = new URL(`${baseUrl}/wiki/rest/api/content/${encodeURIComponent(pageId)}`);
	url.searchParams.set("expand", exp);

	const data = await fetchJson(
		url.toString(),
		{
			method: "GET",
			headers: {
				accept: "application/json",
				authorization: basicAuthHeader(email, apiToken),
			},
		},
		signal
	);

	let bodyContent = data?.body
		? {
			export_view: data.body.export_view?.value ?? null,
			storage: data.body.storage?.value ?? null,
		}
		: null;

	// Auto-convert to Markdown if requested
	if (format === "markdown" && bodyContent?.export_view) {
		const md = await convertToMarkdown(bodyContent.export_view);
		bodyContent = { ...bodyContent, markdown: md };
	}

	// Optionally fetch direct child pages (one level)
	const include_children = !!includeChildren;

	async function fetchChildPages(rootId: string) {
		const children: Array<{ id: string; title?: string }> = [];
		let start = 0;
		const limit = 25;
		while (true) {
			const childUrl = new URL(`${baseUrl}/wiki/rest/api/content/${encodeURIComponent(rootId)}/child/page`);
			childUrl.searchParams.set("limit", String(limit));
			childUrl.searchParams.set("start", String(start));
			const resp = await fetchJson(
				childUrl.toString(),
				{
					method: "GET",
					headers: { accept: "application/json", authorization: basicAuthHeader(email, apiToken) },
				},
				signal
			);
			const results = resp?.results ?? [];
			for (const r of results) {
				children.push({ id: r.id, title: r.title });
			}
			if (results.length < limit) break;
			start += limit;
		}
		return children;
	}

	let childrenResult: Array<{ id: string; title?: string }> = [];
	if (include_children) {
		try {
			childrenResult = await fetchChildPages(pageId);
		} catch (e) {
			// ignore and return what we have
			console.error("Failed to fetch child pages:", e);
		}
	}

	return {
		page_id: data?.id,
		title: data?.title,
		type: data?.type,
		status: data?.status,
		space: data?.space ? { id: data.space.id, key: data.space.key, name: data.space.name } : null,
		body: bodyContent,
		version: data?.version,
		created: data?.history?.createdDate,
		updated: data?.version?.when,
		_links: data?._links,
		children: childrenResult,
	};
}

async function searchJiraChildrenIssues(parentKey: string, parentId: string | null, isEpic: boolean, signal: AbortSignal | undefined) {
	const { email, apiToken } = requireEnv();
	const baseUrl = "https://smec.atlassian.net";

	async function runSearch(jql: string) {
		// Use v3 search/jql endpoint (required on this Jira instance; /search returns HTTP 410)
		const searchUrl = new URL(`${baseUrl}/rest/api/3/search/jql`);
		searchUrl.searchParams.set("jql", jql);
		searchUrl.searchParams.set("maxResults", "50");
		searchUrl.searchParams.set("fields", "summary,issuetype,status,parent");
		const searchRes = await fetchJson(
			searchUrl.toString(),
			{ method: "GET", headers: { accept: "application/json", authorization: basicAuthHeader(email, apiToken) } },
			signal
		);
		const issues = searchRes?.issues ?? [];
		return issues.map((issue: any) => ({
			type: "child",
			id: issue.id ?? null,
			key: issue.key ?? null,
			summary: issue.fields?.summary ?? null,
			issuetype: issue.fields?.issuetype?.name ?? null,
			status: issue.fields?.status?.name ?? null,
		}));
	}

	// If it's an Epic, try Jira Software Agile endpoint first (often more reliable than JQL)
	if (isEpic && parentId) {
		try {
			const agileUrl = new URL(`${baseUrl}/rest/agile/1.0/epic/${encodeURIComponent(parentId)}/issue`);
			agileUrl.searchParams.set("maxResults", "50");
			agileUrl.searchParams.set("fields", "summary,issuetype,status,parent");
			const agileRes = await fetchJson(
				agileUrl.toString(),
				{ method: "GET", headers: { accept: "application/json", authorization: basicAuthHeader(email, apiToken) } },
				signal
			);
			const issues = agileRes?.issues ?? [];
			const mapped = issues.map((issue: any) => ({
				type: "child",
				id: issue.id ?? null,
				key: issue.key ?? null,
				summary: issue.fields?.summary ?? null,
				issuetype: issue.fields?.issuetype?.name ?? null,
				status: issue.fields?.status?.name ?? null,
			}));
			if (mapped.length > 0) return mapped;
		} catch (e) {
			// This endpoint may not be available (Jira Software not installed) or may require permissions
			console.error("Jira children search (agile epic endpoint) failed:", e);
		}
	}

	// Prefer team-managed style (works for PD-6406): parent = KEY
	const parentQueries = [`parent = ${parentKey}`, `parent = "${parentKey}"`];
	for (const q of parentQueries) {
		try {
			const byParent = await runSearch(q);
			if (byParent.length > 0) return byParent;
		} catch (e) {
			console.error(`Jira children search (parent=) failed for jql='${q}':`, e);
		}
	}

	// Fallback for classic/company-managed epics
	try {
		const byEpicLink = await runSearch(`\"Epic Link\" = \"${parentKey}\"`);
		return byEpicLink;
	} catch (e) {
		console.error("Jira children search (Epic Link) failed:", e);
		return [];
	}
}

async function fetchJiraIssueImpl(issueId: string, expand: string | undefined, includeChildren: boolean | undefined, signal: AbortSignal | undefined) {
	const { email, apiToken } = requireEnv();
	const baseUrl = "https://smec.atlassian.net";

	const url = new URL(`${baseUrl}/rest/api/2/issue/${encodeURIComponent(issueId)}`);
	if (expand && expand.trim()) url.searchParams.set("expand", expand);

	const data = await fetchJson(
		url.toString(),
		{
			method: "GET",
			headers: {
				accept: "application/json",
				authorization: basicAuthHeader(email, apiToken),
			},
		},
		signal
	);

	// Build normalized children list if requested (one level)
	const include_children = !!includeChildren;
	const children: Array<any> = [];

	if (include_children) {
		const seenKeys = new Set<string>();
		const pushUnique = (child: any) => {
			const k = child?.key;
			if (typeof k === "string" && k.trim()) {
				if (seenKeys.has(k)) return;
				seenKeys.add(k);
			}
			children.push(child);
		};

		// Subtasks (directly embedded in issue payload)
		if (Array.isArray(data?.fields?.subtasks) && data.fields.subtasks.length > 0) {
			for (const st of data.fields.subtasks) {
				pushUnique({
					type: "subtask",
					id: st.id ?? null,
					key: st.key ?? null,
					summary: st.fields?.summary ?? st.title ?? null,
				});
			}
		}

		// Direct children (one level) via Jira search / agile epic endpoint
		if (data?.key) {
			const isEpic = String(data?.fields?.issuetype?.name ?? "").toLowerCase() === "epic";
			const searchedChildren = await searchJiraChildrenIssues(String(data.key), data?.id ?? null, isEpic, signal);
			for (const c of searchedChildren) pushUnique(c);
		}
	}

	return {
		issue_id: data?.id,
		key: data?.key,
		self: data?.self,
		fields: {
			summary: data?.fields?.summary,
			description: data?.fields?.description,
			status: data?.fields?.status
				? {
					name: data.fields.status.name,
					id: data.fields.status.id,
					statusCategory: data.fields.status.statusCategory,
				}
				: null,
			issuetype: data?.fields?.issuetype ? { name: data.fields.issuetype.name, id: data.fields.issuetype.id } : null,
			project: data?.fields?.project
				? { key: data.fields.project.key, name: data.fields.project.name, id: data.fields.project.id }
				: null,
			assignee: data?.fields?.assignee
				? { displayName: data.fields.assignee.displayName, emailAddress: data.fields.assignee.emailAddress }
				: null,
			reporter: data?.fields?.reporter
				? { displayName: data.fields.reporter.displayName, emailAddress: data.fields.reporter.emailAddress }
				: null,
			priority: data?.fields?.priority ? { name: data.fields.priority.name, id: data.fields.priority.id } : null,
			created: data?.fields?.created,
			updated: data?.fields?.updated,
			resolutiondate: data?.fields?.resolutiondate,
			labels: data?.fields?.labels ?? [],
			components: data?.fields?.components ?? [],
		},
		changelog: data?.changelog,
		_links: data?._links ?? {},
		children: children,
	};
}

type InlineAssetSource = "img" | "a";

type ConfluenceBodySource = "view" | "export_view" | "storage";

const DEFAULT_CONFLUENCE_BASE_URL = "https://smec.atlassian.net";
const DEFAULT_ALLOWED_PATH_PREFIXES = ["/wiki/download/attachments/", "/wiki/download/thumbnails/"];

function extractInlineAssetUrlsFromHtml(html: string, includeLinks: boolean): Array<{ url: string; source: InlineAssetSource }> {
	const out: Array<{ url: string; source: InlineAssetSource }> = [];

	// <img src="..."> or <img src='...'>
	const imgRe = /<img\b[^>]*\bsrc=(?:"([^"]+)"|'([^']+)')/gi;
	for (let m = imgRe.exec(html); m; m = imgRe.exec(html)) {
		const u = (m[1] ?? m[2] ?? "").trim();
		if (u) out.push({ url: u, source: "img" });
	}

	if (includeLinks) {
		// <a href="..."> or <a href='...'>
		const aRe = /<a\b[^>]*\bhref=(?:"([^"]+)"|'([^']+)')/gi;
		for (let m = aRe.exec(html); m; m = aRe.exec(html)) {
			const u = (m[1] ?? m[2] ?? "").trim();
			if (u) out.push({ url: u, source: "a" });
		}
	}

	return out;
}

function normalizeUrl(u: string, baseUrl: string): string | null {
	try {
		return new URL(u, baseUrl).toString();
	} catch {
		return null;
	}
}

function urlPath(u: string): string {
	try {
		return new URL(u).pathname;
	} catch {
		return "";
	}
}

function isAllowedUrl(u: string, allowedPathPrefixes: string[], includeExternal: boolean): boolean {
	if (includeExternal) return true;
	const p = urlPath(u);
	return allowedPathPrefixes.some((prefix) => p.startsWith(prefix));
}

function urlToFilename(u: string): string {
	let name = "asset";
	try {
		const p = new URL(u).pathname;
		const last = p.split("/").filter(Boolean).slice(-1)[0];
		if (last) name = decodeURIComponent(last);
	} catch {
		// ignore
	}

	// Basic sanitization (avoid path traversal)
	name = name.replaceAll("/", "_").replaceAll("\\", "_");
	return name || "asset";
}

async function fetchConfluenceBodyValue(pageId: string, source: ConfluenceBodySource, baseUrl: string, signal?: AbortSignal): Promise<string> {
	const { email, apiToken } = requireEnv();
	const exp = source === "view" ? "body.view" : source === "export_view" ? "body.export_view" : "body.storage";

	const url = new URL(`${baseUrl}/wiki/rest/api/content/${encodeURIComponent(pageId)}`);
	url.searchParams.set("expand", exp);

	const data = await fetchJson(
		url.toString(),
		{
			method: "GET",
			headers: {
				accept: "application/json",
				authorization: basicAuthHeader(email, apiToken),
			},
		},
		signal
	);

	const body = data?.body ?? {};
	const v = source === "view" ? body.view?.value : source === "export_view" ? body.export_view?.value : body.storage?.value;
	if (typeof v !== "string" || !v.trim()) {
		throw new Error(`Confluence page ${pageId} has no body.${source}.value (or it's empty)`);
	}
	return v;
}

async function downloadUrlToFile(url: string, destPath: string, signal?: AbortSignal): Promise<{ bytes: number; contentType: string | null }> {
	const { email, apiToken } = requireEnv();
	const res = await fetch(url, {
		method: "GET",
		headers: {
			authorization: basicAuthHeader(email, apiToken),
		},
		signal,
	});
	if (!res.ok) {
		const text = await res.text().catch(() => "");
		throw new Error(`HTTP ${res.status} ${res.statusText} for ${url}: ${text.slice(0, 500)}`);
	}

	const ab = await res.arrayBuffer();
	const buf = Buffer.from(ab);
	await fs.promises.writeFile(destPath, buf);
	return { bytes: buf.byteLength, contentType: res.headers.get("content-type") };
}

export default function atlassianReaderExtension(pi: ExtensionAPI) {
	pi.registerTool({
		name: "atlassian_chat",
		label: "Atlassian chat",
		description: "Query Atlassian's Jira/Confluence via AI chat gateway.",
		parameters: Type.Object({
			query: Type.String({ description: "Question or search query" }),
			session_id: Type.Optional(Type.String({ description: "Optional session id for continuity" })),
			model_category: Type.Optional(Type.String({ description: "Model category (default: medium)" })),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			try {
				const res = await atlassianChatImpl(params.query, params.session_id, params.model_category, signal);
				return {
					content: [
						{
							type: "text",
							text: `${res.answer}\n\nSession ID: ${res.sessionId}`,
						},
					],
					details: { session_id: res.sessionId },
				};
			} catch (e: any) {
				log(ctx, "ERROR", "atlassian_chat failed", String(e?.message ?? e));
				throw e;
			}
		},
	});

	pi.registerTool({
		name: "fetch_confluence_page",
		label: "Fetch Confluence page",
		description: "Fetch a Confluence page by ID (direct Atlassian Cloud REST API). Optional auto-convert to Markdown.",
		parameters: Type.Object({
			page_id: Type.String({ description: "Confluence page id" }),
			expand: Type.Optional(Type.String({ description: "Confluence expand param" })),
			format: Type.Optional(Type.String({ description: "Output format: 'markdown' for converted content (default: html)" })),
			include_children: Type.Optional(Type.Boolean({ description: "Include child pages (default: false)" })),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			try {
				const res = await fetchConfluencePageImpl(params.page_id, params.expand, params.format, params.include_children, signal);
				// If markdown was requested and successful, prioritize it in the response content for brevity
				if (params.format === "markdown" && res.body?.markdown) {
					return {
						content: [{ type: "text", text: res.body.markdown }],
						details: { title: res.title, space: res.space?.key },
					};
				}
				return {
					content: [{ type: "text", text: JSON.stringify(res, null, 2) }],
					details: {},
				};
			} catch (e: any) {
				log(ctx, "ERROR", "fetch_confluence_page failed", String(e?.message ?? e));
				throw e;
			}
		},
	});

	pi.registerTool({
		name: "download_confluence_inline_assets",
		label: "Download Confluence inline assets",
		description:
			"Download assets (images/attachments) referenced inline in Confluence page HTML (typically <img src=.../download/attachments/...>). Intended to be used after fetching a page.",
		parameters: Type.Object({
			page_id: Type.String({ description: "Confluence page id" }),
			// If provided, this is parsed directly. If omitted, the tool fetches body.view.value from Confluence.
			html: Type.Optional(Type.String({ description: "Rendered page HTML to parse (body.view.value or body.export_view.value)." })),
			base_url: Type.Optional(Type.String({ description: `Confluence base URL (default: ${DEFAULT_CONFLUENCE_BASE_URL})` })),
			body_source: Type.Optional(
				Type.Union([
					Type.Literal("view"),
					Type.Literal("export_view"),
					Type.Literal("storage"),
				])
			),
			out_dir: Type.Optional(Type.String({ description: "Directory to write downloaded files to (default: temp dir)." })),
			include_links: Type.Optional(Type.Boolean({ description: "Also consider <a href=...> URLs (default: true)." })),
			include_external: Type.Optional(Type.Boolean({ description: "Allow downloading non-Confluence-attachment URLs (default: false)." })),
			allowed_path_prefixes: Type.Optional(
				Type.Array(Type.String(), {
					description: "Restrict downloads to URLs whose path starts with one of these prefixes.",
				})
			),
			select_indices: Type.Optional(Type.Array(Type.Number(), { description: "Select assets by discovered index." })),
			select_filename_regex: Type.Optional(Type.String({ description: "Select assets whose filename matches this regex." })),
			select_url_regex: Type.Optional(Type.String({ description: "Select assets whose URL matches this regex." })),
			max: Type.Optional(Type.Number({ description: "Maximum number of assets to download (default: 50)." })),
			dry_run: Type.Optional(Type.Boolean({ description: "If true, only list discovered assets; do not download." })),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			try {
				const baseUrl = (params.base_url ?? DEFAULT_CONFLUENCE_BASE_URL).replace(/\/$/, "");
				const includeLinks = params.include_links ?? true;
				const includeExternal = params.include_external ?? false;
				const allowedPrefixes = params.allowed_path_prefixes ?? DEFAULT_ALLOWED_PATH_PREFIXES;
				const max = typeof params.max === "number" && params.max > 0 ? params.max : 50;
				const dryRun = params.dry_run ?? false;

				const bodySource: ConfluenceBodySource = (params.body_source as any) ?? "view";

				const html =
					typeof params.html === "string" && params.html.trim()
						? params.html
						: await fetchConfluenceBodyValue(params.page_id, bodySource, baseUrl, signal);

				const raw = extractInlineAssetUrlsFromHtml(html, includeLinks);

				// normalize, filter, dedupe
				const discovered: Array<{ index: number; url: string; filename: string; source: InlineAssetSource }> = [];
				const seen = new Set<string>();
				for (const r of raw) {
					const norm = normalizeUrl(r.url, baseUrl);
					if (!norm) continue;
					if (!isAllowedUrl(norm, allowedPrefixes, includeExternal)) continue;
					if (seen.has(norm)) continue;
					seen.add(norm);
					discovered.push({ index: discovered.length, url: norm, filename: urlToFilename(norm), source: r.source });
					if (discovered.length >= 500) break; // hard safety cap
				}

				let filenameRe: RegExp | null = null;
				let urlRe: RegExp | null = null;
				try {
					if (params.select_filename_regex) filenameRe = new RegExp(params.select_filename_regex);
				} catch (e: any) {
					throw new Error(`Invalid select_filename_regex: ${String(e?.message ?? e)}`);
				}
				try {
					if (params.select_url_regex) urlRe = new RegExp(params.select_url_regex);
				} catch (e: any) {
					throw new Error(`Invalid select_url_regex: ${String(e?.message ?? e)}`);
				}

				const indexSet = new Set<number>((params.select_indices ?? []).filter((n: any) => typeof n === "number"));
				const hasSelector = indexSet.size > 0 || !!filenameRe || !!urlRe;

				let selected = discovered;
				if (hasSelector) {
					selected = discovered.filter((a) => {
						if (indexSet.size > 0 && indexSet.has(a.index)) return true;
						if (filenameRe && filenameRe.test(a.filename)) return true;
						if (urlRe && urlRe.test(a.url)) return true;
						return false;
					});
				}

				selected = selected.slice(0, max);

				const outDir =
					typeof params.out_dir === "string" && params.out_dir.trim()
						? params.out_dir
						: path.join(os.tmpdir(), `confluence-inline-assets-${params.page_id}-${Date.now()}`);
				await fs.promises.mkdir(outDir, { recursive: true });

				const downloaded: Array<any> = [];
				const usedNames = new Map<string, number>();

				if (!dryRun) {
					for (const a of selected) {
						const n = usedNames.get(a.filename) ?? 0;
						usedNames.set(a.filename, n + 1);
						const baseName = n === 0 ? a.filename : `${path.parse(a.filename).name}__${n}${path.parse(a.filename).ext}`;
						const dest = path.join(outDir, baseName);
						const res = await downloadUrlToFile(a.url, dest, signal);
						downloaded.push({ ...a, saved_as: dest, bytes: res.bytes, content_type: res.contentType });
					}
				}

				const manifest = {
					page_id: params.page_id,
					base_url: baseUrl,
					body_source: bodySource,
					out_dir: outDir,
					dry_run: dryRun,
					discovered,
					selected,
					downloaded,
				};

				return {
					content: [{ type: "text", text: JSON.stringify(manifest, null, 2) }],
					details: { out_dir: outDir, downloaded: String(downloaded.length), discovered: String(discovered.length) },
				};
			} catch (e: any) {
				log(ctx, "ERROR", "download_confluence_inline_assets failed", String(e?.message ?? e));
				throw e;
			}
		},
	});

	pi.registerTool({
		name: "fetch_jira_issue",
		label: "Fetch Jira issue",
		description: "Fetch a Jira issue by key/id (direct Atlassian Cloud REST API).",
		parameters: Type.Object({
			issue_id: Type.String({ description: "Jira issue key or id (e.g. PROJ-123)" }),
			expand: Type.Optional(Type.String({ description: "Jira expand param" })),
			include_children: Type.Optional(Type.Boolean({ description: "Include child issues (subtasks/epic children) (default: false)" })),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			try {
				const res = await fetchJiraIssueImpl(params.issue_id, params.expand, params.include_children, signal);
				return {
					content: [{ type: "text", text: JSON.stringify(res, null, 2) }],
					details: {},
				};
			} catch (e: any) {
				log(ctx, "ERROR", "fetch_jira_issue failed", String(e?.message ?? e));
				throw e;
			}
		},
	});

	// Convenience commands (manual use)
	pi.registerCommand("atlassian-chat", {
		description: "Run atlassian_chat for a query (usage: /atlassian-chat <query>)",
		handler: async (args, ctx) => {
			const query = args.trim();
			if (!query) {
				ctx.ui.notify("Usage: /atlassian-chat <query>", "info");
				return;
			}
			ctx.ui.setStatus("atlassian-reader", "Querying Atlassian...");
			try {
				const res = await atlassianChatImpl(query, undefined, "medium", undefined);
				const lines = String(res.answer).split("\n");
				const max = 30;
				ctx.ui.setWidget(
					"atlassian-reader",
					(lines.length > max ? lines.slice(0, max).concat(["… (truncated)"]) : lines).slice(0, max + 1)
				);
				ctx.ui.notify(`Done. Session ID: ${res.sessionId}`, "success");
			} finally {
				ctx.ui.setStatus("atlassian-reader", "");
			}
		},
	});

	pi.registerCommand("atlassian-jira", {
		description: "Fetch a Jira issue (usage: /atlassian-jira <issueKey>)",
		handler: async (args, ctx) => {
			const issueId = args.trim();
			if (!issueId) {
				ctx.ui.notify("Usage: /atlassian-jira <issueKey>", "info");
				return;
			}
			ctx.ui.setStatus("atlassian-reader", "Fetching Jira issue...");
			try {
				const res = await fetchJiraIssueImpl(issueId, undefined, undefined, undefined);
				ctx.ui.setWidget("atlassian-reader", [
					`Key: ${res.key}`,
					`Summary: ${res.fields?.summary ?? ""}`,
					`Status: ${res.fields?.status?.name ?? ""}`,
				]);
				ctx.ui.notify("Done.", "success");
			} finally {
				ctx.ui.setStatus("atlassian-reader", "");
			}
		},
	});

	pi.registerCommand("atlassian-confluence", {
		description: "Fetch a Confluence page (usage: /atlassian-confluence <pageId>)",
		handler: async (args, ctx) => {
			const pageId = args.trim();
			if (!pageId) {
				ctx.ui.notify("Usage: /atlassian-confluence <pageId>", "info");
				return;
			}
			ctx.ui.setStatus("atlassian-reader", "Fetching Confluence page...");
			try {
				const res = await fetchConfluencePageImpl(pageId, undefined, undefined, undefined, undefined);
				ctx.ui.setWidget("atlassian-reader", [`Title: ${res.title ?? ""}`, `Space: ${res.space?.key ?? ""}`]);
				ctx.ui.notify("Done.", "success");
			} finally {
				ctx.ui.setStatus("atlassian-reader", "");
			}
		},
	});
}
