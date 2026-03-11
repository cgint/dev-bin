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

type RecentConfluencePageChangeSummary = {
	from_version: number | null;
	to_version: number | null;
	previous_modified: string | null;
	previous_modifier: string | null;
	title_changed: boolean;
	current_text_length: number | null;
	previous_text_length: number | null;
	text_length_delta: number | null;
	added_excerpt: string | null;
};

type RecentConfluencePage = {
	id: string | null;
	title: string | null;
	type: string | null;
	status: string | null;
	space_key: string | null;
	space_name: string | null;
	last_modified: string | null;
	last_modifier: string | null;
	version_number: number | null;
	url: string | null;
	change_summary?: RecentConfluencePageChangeSummary | null;
};

function toConfluenceCqlDate(isoDate: string): string {
	const date = new Date(isoDate);
	if (Number.isNaN(date.getTime())) {
		throw new Error(`Invalid since value '${isoDate}'. Expected ISO date, e.g. 2026-03-10T00:00:00Z`);
	}
	const pad = (n: number) => String(n).padStart(2, "0");
	return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())} ${pad(date.getUTCHours())}:${pad(date.getUTCMinutes())}`;
}

function decodeBasicHtmlEntities(text: string): string {
	const named: Record<string, string> = {
		nbsp: " ",
		amp: "&",
		lt: "<",
		gt: ">",
		quot: '"',
		apos: "'",
		ouml: "ö",
		Ouml: "Ö",
		uuml: "ü",
		Uuml: "Ü",
		äuml: "ä",
		Auml: "Ä",
		auml: "ä",
		eszlig: "ß",
		szlig: "ß",
		euro: "€",
		ndash: "–",
		mdash: "—",
		hellip: "…",
		laquo: "«",
		raquo: "»",
		lsquo: "‘",
		rsquo: "’",
		ldquo: "“",
		rdquo: "”",
		middot: "·",
		copy: "©",
		reg: "®",
	};

	return text
		.replace(/&#(\d+);/g, (_match, dec) => {
			const codePoint = Number.parseInt(dec, 10);
			return Number.isFinite(codePoint) ? String.fromCodePoint(codePoint) : _match;
		})
		.replace(/&#x([0-9a-fA-F]+);/g, (_match, hex) => {
			const codePoint = Number.parseInt(hex, 16);
			return Number.isFinite(codePoint) ? String.fromCodePoint(codePoint) : _match;
		})
		.replace(/&([a-zA-Z][a-zA-Z0-9]+);/g, (match, name) => named[name] ?? match);
}

function normalizeWhitespace(text: string): string {
	return decodeBasicHtmlEntities(text).replace(/\s+/g, " ").trim();
}

function normalizeDiffBlock(text: string): string {
	return normalizeWhitespace(text).toLowerCase();
}

function isUrlOnlyText(text: string): boolean {
	const trimmed = text.trim();
	return /^https?:\/\/\S+$/i.test(trimmed);
}

function isUsefulDiffBlock(text: string): boolean {
	const trimmed = normalizeWhitespace(text);
	if (!trimmed) return false;
	if (trimmed.length < 12) return false;
	if (isUrlOnlyText(trimmed)) return false;
	if (/^[\d\s\W_]+$/.test(trimmed)) return false;
	return true;
}

function extractTextBlocks(html: string): string[] {
	const withBreaks = html
		.replace(/<style[\s\S]*?<\/style>/gi, "\n")
		.replace(/<script[\s\S]*?<\/script>/gi, "\n")
		.replace(/<br\s*\/?>/gi, "\n")
		.replace(/<\/(?:p|div|li|tr|td|th|h[1-6]|section|article|ul|ol|table|blockquote)>/gi, "\n")
		.replace(/<(?:p|div|li|tr|td|th|h[1-6]|section|article|ul|ol|table|blockquote)\b[^>]*>/gi, "\n")
		.replace(/<[^>]+>/g, " ");

	return withBreaks
		.split(/\n+/)
		.map((part) => normalizeWhitespace(part))
		.filter(Boolean);
}

function stripHtml(html: string): string {
	return extractTextBlocks(html).join(" ");
}

function findAddedExcerpt(previousHtmlOrText: string, currentHtmlOrText: string, maxLength = 220): string | null {
	const previousBlocks = previousHtmlOrText.includes("<") ? extractTextBlocks(previousHtmlOrText) : previousHtmlOrText.split(/\n+/).map((s) => normalizeWhitespace(s)).filter(Boolean);
	const currentBlocks = currentHtmlOrText.includes("<") ? extractTextBlocks(currentHtmlOrText) : currentHtmlOrText.split(/\n+/).map((s) => normalizeWhitespace(s)).filter(Boolean);
	const previousSet = new Set(previousBlocks.map((block) => normalizeDiffBlock(block)));

	const addedBlocks = currentBlocks.filter((block) => {
		const normalized = normalizeDiffBlock(block);
		return !previousSet.has(normalized) && isUsefulDiffBlock(block);
	});

	if (addedBlocks.length > 0) {
		addedBlocks.sort((a, b) => b.length - a.length);
		return addedBlocks[0].slice(0, maxLength);
	}

	const previousText = normalizeWhitespace(previousBlocks.join(" "));
	const currentText = normalizeWhitespace(currentBlocks.join(" "));
	if (!currentText || currentText === previousText) return null;

	let prefix = 0;
	while (
		prefix < previousText.length &&
		prefix < currentText.length &&
		previousText.charCodeAt(prefix) === currentText.charCodeAt(prefix)
	) {
		prefix += 1;
	}

	let prevSuffix = previousText.length - 1;
	let currSuffix = currentText.length - 1;
	while (
		prevSuffix >= prefix &&
		currSuffix >= prefix &&
		previousText.charCodeAt(prevSuffix) === currentText.charCodeAt(currSuffix)
	) {
		prevSuffix -= 1;
		currSuffix -= 1;
	}

	const added = currentText.slice(prefix, currSuffix + 1).trim();
	if (!isUsefulDiffBlock(added)) return null;
	return added.slice(0, maxLength);
}

async function fetchConfluencePageVersionPayload(pageId: string, versionNumber: number, signal?: AbortSignal): Promise<{
	title: string | null;
	version_number: number | null;
	modified: string | null;
	modifier: string | null;
	body_storage: string;
}> {
	const { email, apiToken } = requireEnv();
	const baseUrl = DEFAULT_CONFLUENCE_BASE_URL;
	const url = new URL(`${baseUrl}/wiki/rest/api/content/${encodeURIComponent(pageId)}/version/${versionNumber}`);
	url.searchParams.set("expand", "content.body.storage,by");

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

	const content = data?.content ?? {};
	return {
		title: content?.title ?? null,
		version_number: typeof data?.number === "number" ? data.number : null,
		modified: data?.when ?? null,
		modifier: data?.by?.displayName ?? null,
		body_storage: content?.body?.storage?.value ?? "",
	};
}

async function buildRecentConfluencePageChangeSummary(page: RecentConfluencePage, signal?: AbortSignal): Promise<RecentConfluencePageChangeSummary | null> {
	if (!page.id || !page.version_number || page.version_number <= 1) {
		return null;
	}

	const currentVersion = page.version_number;
	const previousVersion = currentVersion - 1;
	const [previous, current] = await Promise.all([
		fetchConfluencePageVersionPayload(page.id, previousVersion, signal),
		fetchConfluencePageVersionPayload(page.id, currentVersion, signal),
	]);

	const previousText = stripHtml(previous.body_storage);
	const currentText = stripHtml(current.body_storage);

	return {
		from_version: previous.version_number,
		to_version: current.version_number,
		previous_modified: previous.modified,
		previous_modifier: previous.modifier,
		title_changed: (previous.title ?? "") !== (current.title ?? ""),
		current_text_length: currentText.length,
		previous_text_length: previousText.length,
		text_length_delta: currentText.length - previousText.length,
		added_excerpt: findAddedExcerpt(previous.body_storage, current.body_storage),
	};
}

function normalizeRecentConfluencePage(item: any): RecentConfluencePage {
	const content = item?.content ?? item;
	const links = content?._links ?? item?._links ?? {};
	const webui = links.webui ?? links.tinyui ?? null;
	const url = webui ? new URL(webui, `${DEFAULT_CONFLUENCE_BASE_URL}/wiki`).toString() : null;

	return {
		id: content?.id ?? null,
		title: content?.title ?? item?.title ?? null,
		type: content?.type ?? item?.entityType ?? null,
		status: content?.status ?? null,
		space_key: content?.space?.key ?? item?.space?.key ?? null,
		space_name: content?.space?.name ?? item?.space?.name ?? null,
		last_modified: content?.version?.when ?? item?.lastModified ?? null,
		last_modifier: content?.version?.by?.displayName ?? item?.friendlyLastModifiedBy ?? null,
		version_number: typeof content?.version?.number === "number" ? content.version.number : null,
		url,
	};
}

function escapeMarkdownCell(value: string | number | null | undefined): string {
	return String(value ?? "").replace(/\|/g, "\\|").replace(/\n/g, " ");
}

function renderRecentConfluencePagesMarkdown(pages: RecentConfluencePage[]): string {
	if (pages.length === 0) return "No pages returned.";
	const lines = [
		"| Space | Title | Modified | By | Version | Change | URL |",
		"|---|---|---|---|---:|---|---|",
	];
	for (const page of pages) {
		const title = page.url ? `[${escapeMarkdownCell(page.title ?? "(no title)")}](${page.url})` : escapeMarkdownCell(page.title ?? "(no title)");
		const version = page.version_number ?? "";
		const change = page.change_summary
			? `v${page.change_summary.from_version ?? "?"}→v${page.change_summary.to_version ?? "?"}; Δ ${page.change_summary.text_length_delta ?? "?"}${page.change_summary.title_changed ? "; title changed" : ""}${page.change_summary.added_excerpt ? `; ${escapeMarkdownCell(page.change_summary.added_excerpt)}` : ""}`
			: "";
		const url = page.url ? `[link](${page.url})` : "";
		lines.push(`| ${escapeMarkdownCell(page.space_key)} | ${title} | ${escapeMarkdownCell(page.last_modified)} | ${escapeMarkdownCell(page.last_modifier)} | ${escapeMarkdownCell(version)} | ${change} | ${url} |`);
	}
	return lines.join("\n");
}

async function fetchRecentConfluencePagesImpl(
	limit: number | undefined,
	since: string | undefined,
	spaceKeys: string[] | undefined,
	format: string | undefined,
	includeChangeSummary: boolean | undefined,
	signal?: AbortSignal
) {
	const { email, apiToken } = requireEnv();
	const baseUrl = DEFAULT_CONFLUENCE_BASE_URL;
	const headers = {
		accept: "application/json",
		authorization: basicAuthHeader(email, apiToken),
	};
	const maxResults = typeof limit === "number" && limit > 0 ? limit : 25;
	const requestedFormat = format === "markdown" ? "markdown" : "json";

	const filters = ["type = page"];
	const normalizedSpaceKeys = (spaceKeys ?? []).map((v) => v.trim()).filter(Boolean);
	if (normalizedSpaceKeys.length === 1) {
		filters.push(`space = "${normalizedSpaceKeys[0]}"`);
	} else if (normalizedSpaceKeys.length > 1) {
		filters.push(`space in ("${normalizedSpaceKeys.join(`","`)}")`);
	}
	if (since && since.trim()) {
		filters.push(`lastmodified >= "${toConfluenceCqlDate(since.trim())}"`);
	}
	const cql = `${filters.join(" and ")} order by lastmodified desc`;

	const endpointCandidates = [
		"/wiki/rest/api/content/search",
		"/wiki/rest/api/search",
	];
	let lastError: unknown;

	for (const endpoint of endpointCandidates) {
		const url = new URL(endpoint, baseUrl);
		url.searchParams.set("cql", cql);
		url.searchParams.set("limit", String(maxResults));
		url.searchParams.set("expand", "space,version");

		try {
			const data = await fetchJson(url.toString(), { method: "GET", headers }, signal);
			const rawResults = Array.isArray(data?.results) ? data.results : [];
			const pages: RecentConfluencePage[] = rawResults.map((item: any) => normalizeRecentConfluencePage(item));

			if (includeChangeSummary) {
				for (const page of pages) {
					try {
						page.change_summary = await buildRecentConfluencePageChangeSummary(page, signal);
					} catch (e: any) {
						page.change_summary = {
							from_version: page.version_number && page.version_number > 1 ? page.version_number - 1 : null,
							to_version: page.version_number ?? null,
							previous_modified: null,
							previous_modifier: null,
							title_changed: false,
							current_text_length: null,
							previous_text_length: null,
							text_length_delta: null,
							added_excerpt: `[change summary failed: ${String(e?.message ?? e)}]`,
						};
					}
				}
			}

			return {
				endpoint,
				cql,
				count: rawResults.length,
				pages,
				text: requestedFormat === "markdown" ? renderRecentConfluencePagesMarkdown(pages) : JSON.stringify({ endpoint, cql, count: rawResults.length, pages }, null, 2),
			};
		} catch (e) {
			lastError = e;
		}
	}

	throw lastError instanceof Error ? lastError : new Error(String(lastError));
}

type ConfluencePageHistoryVersion = {
	version_number: number | null;
	modified: string | null;
	friendly_modified: string | null;
	modifier: string | null;
	message: string | null;
	minor_edit: boolean | null;
};

type ConfluencePageVersionDiff = {
	from_version: number | null;
	to_version: number | null;
	from_modified: string | null;
	to_modified: string | null;
	from_modifier: string | null;
	to_modifier: string | null;
	title_changed: boolean;
	current_text_length: number | null;
	previous_text_length: number | null;
	text_length_delta: number | null;
	added_excerpt: string | null;
};

async function fetchConfluencePageMetadata(pageId: string, signal?: AbortSignal): Promise<{
	page_id: string | null;
	title: string | null;
	space: { id: string | null; key: string | null; name: string | null } | null;
	current_version: number | null;
	updated: string | null;
	url: string | null;
}> {
	const { email, apiToken } = requireEnv();
	const baseUrl = DEFAULT_CONFLUENCE_BASE_URL;
	const url = new URL(`${baseUrl}/wiki/rest/api/content/${encodeURIComponent(pageId)}`);
	url.searchParams.set("expand", "space,version");

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

	const webui = data?._links?.webui ?? null;
	return {
		page_id: data?.id ?? null,
		title: data?.title ?? null,
		space: data?.space ? { id: data.space.id ?? null, key: data.space.key ?? null, name: data.space.name ?? null } : null,
		current_version: typeof data?.version?.number === "number" ? data.version.number : null,
		updated: data?.version?.when ?? null,
		url: webui ? new URL(webui, `${baseUrl}/wiki`).toString() : null,
	};
}

async function fetchConfluencePageHistoryVersions(pageId: string, limit: number, signal?: AbortSignal): Promise<ConfluencePageHistoryVersion[]> {
	const { email, apiToken } = requireEnv();
	const baseUrl = DEFAULT_CONFLUENCE_BASE_URL;
	const url = new URL(`${baseUrl}/wiki/rest/api/content/${encodeURIComponent(pageId)}/version`);
	url.searchParams.set("limit", String(limit));

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

	const results = Array.isArray(data?.results) ? data.results : [];
	return results.map((item: any) => ({
		version_number: typeof item?.number === "number" ? item.number : null,
		modified: item?.when ?? null,
		friendly_modified: item?.friendlyWhen ?? null,
		modifier: item?.by?.displayName ?? null,
		message: item?.message ?? null,
		minor_edit: typeof item?.minorEdit === "boolean" ? item.minorEdit : null,
	}));
}

async function buildConfluencePageVersionDiff(pageId: string, fromVersion: number, toVersion: number, signal?: AbortSignal): Promise<ConfluencePageVersionDiff> {
	const [from, to] = await Promise.all([
		fetchConfluencePageVersionPayload(pageId, fromVersion, signal),
		fetchConfluencePageVersionPayload(pageId, toVersion, signal),
	]);

	const fromText = stripHtml(from.body_storage);
	const toText = stripHtml(to.body_storage);

	return {
		from_version: from.version_number,
		to_version: to.version_number,
		from_modified: from.modified,
		to_modified: to.modified,
		from_modifier: from.modifier,
		to_modifier: to.modifier,
		title_changed: (from.title ?? "") !== (to.title ?? ""),
		current_text_length: toText.length,
		previous_text_length: fromText.length,
		text_length_delta: toText.length - fromText.length,
		added_excerpt: findAddedExcerpt(from.body_storage, to.body_storage),
	};
}

function renderConfluencePageHistoryMarkdown(data: {
	page_id: string | null;
	title: string | null;
	space: { id: string | null; key: string | null; name: string | null } | null;
	current_version: number | null;
	updated: string | null;
	url: string | null;
	versions: ConfluencePageHistoryVersion[];
	diff: ConfluencePageVersionDiff | null;
}): string {
	const lines: string[] = [];
	lines.push(`# ${data.title ?? "Confluence page"}`);
	lines.push("");
	lines.push(`- Page ID: ${data.page_id ?? "?"}`);
	lines.push(`- Space: ${data.space?.key ?? "?"}${data.space?.name ? ` (${data.space.name})` : ""}`);
	lines.push(`- Current version: ${data.current_version ?? "?"}`);
	lines.push(`- Updated: ${data.updated ?? "?"}`);
	if (data.url) lines.push(`- URL: ${data.url}`);
	lines.push("");
	lines.push("## Versions");
	lines.push("");

	if (data.versions.length === 0) {
		lines.push("No versions returned.");
	} else {
		lines.push("| Version | Modified | By | Minor | Message |",
			"|---:|---|---|---|---|");
		for (const version of data.versions) {
			lines.push(`| ${escapeMarkdownCell(version.version_number)} | ${escapeMarkdownCell(version.modified ?? version.friendly_modified)} | ${escapeMarkdownCell(version.modifier)} | ${escapeMarkdownCell(version.minor_edit)} | ${escapeMarkdownCell(version.message)} |`);
		}
	}

	if (data.diff) {
		lines.push("", "## Diff summary", "");
		lines.push(`- Versions: v${data.diff.from_version ?? "?"} → v${data.diff.to_version ?? "?"}`);
		lines.push(`- Modified: ${data.diff.from_modified ?? "?"} → ${data.diff.to_modified ?? "?"}`);
		lines.push(`- Editors: ${data.diff.from_modifier ?? "?"} → ${data.diff.to_modifier ?? "?"}`);
		lines.push(`- Text length delta: ${data.diff.text_length_delta ?? "?"}`);
		lines.push(`- Title changed: ${data.diff.title_changed}`);
		if (data.diff.added_excerpt) lines.push(`- Added excerpt: ${data.diff.added_excerpt}`);
	}

	return lines.join("\n");
}

async function fetchConfluencePageHistoryImpl(
	pageId: string,
	limit: number | undefined,
	format: string | undefined,
	includeDiff: boolean | undefined,
	fromVersion: number | undefined,
	toVersion: number | undefined,
	signal?: AbortSignal
) {
	const maxResults = typeof limit === "number" && limit > 0 ? limit : 10;
	const requestedFormat = format === "markdown" ? "markdown" : "json";
	const metadata = await fetchConfluencePageMetadata(pageId, signal);
	const versions = await fetchConfluencePageHistoryVersions(pageId, maxResults, signal);

	let diff: ConfluencePageVersionDiff | null = null;
	if (includeDiff) {
		let resolvedTo = typeof toVersion === "number" && toVersion > 0 ? toVersion : undefined;
		let resolvedFrom = typeof fromVersion === "number" && fromVersion > 0 ? fromVersion : undefined;

		if (resolvedTo === undefined && versions.length > 0 && typeof versions[0]?.version_number === "number") {
			resolvedTo = versions[0].version_number as number;
		}
		if (resolvedFrom === undefined) {
			if (resolvedTo !== undefined && resolvedTo > 1) {
				resolvedFrom = resolvedTo - 1;
			} else if (versions.length > 1 && typeof versions[1]?.version_number === "number") {
				resolvedFrom = versions[1].version_number as number;
			}
		}

		if (resolvedFrom === undefined || resolvedTo === undefined) {
			throw new Error(`Could not resolve diff versions for page ${pageId}. Provide from_version/to_version or request a page with at least two versions.`);
		}
		if (resolvedFrom >= resolvedTo) {
			throw new Error(`from_version (${resolvedFrom}) must be less than to_version (${resolvedTo}).`);
		}

		diff = await buildConfluencePageVersionDiff(pageId, resolvedFrom, resolvedTo, signal);
	}

	const result = {
		page_id: metadata.page_id,
		title: metadata.title,
		space: metadata.space,
		current_version: metadata.current_version,
		updated: metadata.updated,
		url: metadata.url,
		versions,
		diff,
	};

	return {
		...result,
		text: requestedFormat === "markdown" ? renderConfluencePageHistoryMarkdown(result) : JSON.stringify(result, null, 2),
	};
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
		name: "fetch_recent_confluence_pages",
		label: "Fetch recent Confluence pages",
		description: "List recently updated Confluence pages visible to the authenticated user, optionally filtered by time or space.",
		parameters: Type.Object({
			limit: Type.Optional(Type.Number({ description: "Maximum number of pages to return (default: 25)" })),
			since: Type.Optional(Type.String({ description: "Only include pages modified since this ISO timestamp (e.g. 2026-03-10T00:00:00Z)" })),
			space_keys: Type.Optional(Type.Array(Type.String(), { description: "Optional Confluence space keys to restrict the search." })),
			format: Type.Optional(Type.String({ description: "Output format: 'markdown' or 'json' (default: json)" })),
			include_change_summary: Type.Optional(Type.Boolean({ description: "Include a lightweight previous-vs-current change summary per page (default: false)." })),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			try {
				const res = await fetchRecentConfluencePagesImpl(
					params.limit,
					params.since,
					params.space_keys,
					params.format,
					params.include_change_summary,
					signal
				);
				return {
					content: [{ type: "text", text: res.text }],
					details: { endpoint: res.endpoint, count: String(res.count), cql: res.cql },
				};
			} catch (e: any) {
				log(ctx, "ERROR", "fetch_recent_confluence_pages failed", String(e?.message ?? e));
				throw e;
			}
		},
	});

	pi.registerTool({
		name: "fetch_confluence_page_history",
		label: "Fetch Confluence page history",
		description: "Fetch version history for a Confluence page, with optional compare/diff summary between two versions.",
		parameters: Type.Object({
			page_id: Type.String({ description: "Confluence page id" }),
			limit: Type.Optional(Type.Number({ description: "Maximum number of history entries to return (default: 10)" })),
			format: Type.Optional(Type.String({ description: "Output format: 'markdown' or 'json' (default: json)" })),
			include_diff: Type.Optional(Type.Boolean({ description: "Include a lightweight diff summary between two page versions (default: false)." })),
			from_version: Type.Optional(Type.Number({ description: "Optional source version for diff comparison." })),
			to_version: Type.Optional(Type.Number({ description: "Optional target version for diff comparison." })),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			try {
				const res = await fetchConfluencePageHistoryImpl(
					params.page_id,
					params.limit,
					params.format,
					params.include_diff,
					params.from_version,
					params.to_version,
					signal
				);
				return {
					content: [{ type: "text", text: res.text }],
					details: { page_id: String(res.page_id ?? params.page_id), current_version: String(res.current_version ?? ""), versions: String(res.versions.length) },
				};
			} catch (e: any) {
				log(ctx, "ERROR", "fetch_confluence_page_history failed", String(e?.message ?? e));
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
