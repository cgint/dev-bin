import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

type LogLevel = "INFO" | "ERROR";

function log(ctx: any, level: LogLevel, message: string, data?: unknown) {
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
		throw new Error(
			`HTTP ${res.status} ${res.statusText}: ${typeof data === "string" ? data : JSON.stringify(data)}`
		);
	}
	return data;
}

type AdfDoc = {
	type: "doc";
	version: 1;
	content: Array<any>;
};

function adfFromPlainText(text: string): AdfDoc {
	const normalized = String(text ?? "").replace(/\r\n/g, "\n");
	const trimmed = normalized.trim();
	if (!trimmed) {
		return { type: "doc", version: 1, content: [] };
	}

	// Split into paragraphs by blank lines, but preserve single newlines as hardBreaks.
	const paragraphs = trimmed
		.split(/\n\s*\n/g)
		.map((p) => p.trim())
		.filter(Boolean);

	return {
		type: "doc",
		version: 1,
		content: paragraphs.map((p) => {
			const lines = p.split(/\n/);
			const content: any[] = [];
			for (let i = 0; i < lines.length; i++) {
				const line = lines[i];
				content.push({ type: "text", text: line });
				if (i < lines.length - 1) content.push({ type: "hardBreak" });
			}
			return { type: "paragraph", content };
		}),
	};
}

function appendAdf(existing: any | null | undefined, appendText: string): AdfDoc {
	const toAppend = adfFromPlainText(appendText);
	if (!existing || typeof existing !== "object") return toAppend;
	if (existing.type !== "doc") return toAppend;
	const existingContent = Array.isArray(existing.content) ? existing.content : [];
	return {
		type: "doc",
		version: 1,
		content: [...existingContent, ...(toAppend.content ?? [])],
	};
}

async function jiraGetIssueFields(issueKey: string, fields: string, signal?: AbortSignal) {
	const { email, apiToken } = requireEnv();
	const baseUrl = "https://smec.atlassian.net";
	const url = new URL(`${baseUrl}/rest/api/3/issue/${encodeURIComponent(issueKey)}`);
	url.searchParams.set("fields", fields);
	return fetchJson(
		url.toString(),
		{ method: "GET", headers: { accept: "application/json", authorization: basicAuthHeader(email, apiToken) } },
		signal
	);
}

async function jiraUpdateIssueImpl(
	params: {
		issue_key: string;
		summary?: string;
		description_text?: string;
		description_mode?: "overwrite" | "append";
		confirm?: boolean;
	},
	signal?: AbortSignal
) {
	const { email, apiToken } = requireEnv();
	const baseUrl = "https://smec.atlassian.net";
	const confirm = params.confirm === true;
	const mode = params.description_mode ?? "overwrite";

	const issueKey = params.issue_key;
	if (!issueKey?.trim()) throw new Error("issue_key is required");

	const fields: Record<string, any> = {};
	if (typeof params.summary === "string") {
		const s = params.summary.trim();
		if (!s) throw new Error("summary must not be empty if provided");
		fields.summary = s;
	}

	if (typeof params.description_text === "string") {
		if (mode === "append") {
			const existing = await jiraGetIssueFields(issueKey, "description", signal);
			fields.description = appendAdf(existing?.fields?.description, params.description_text);
		} else {
			fields.description = adfFromPlainText(params.description_text);
		}
	}

	const payload = { fields };

	if (!confirm) {
		return {
			dry_run: true,
			request: {
				method: "PUT",
				url: `${baseUrl}/rest/api/3/issue/${issueKey}`,
				body: payload,
			},
		};
	}

	if (Object.keys(fields).length === 0) {
		throw new Error("Nothing to update: provide summary and/or description_text");
	}

	const url = `${baseUrl}/rest/api/3/issue/${encodeURIComponent(issueKey)}`;
	await fetchJson(
		url,
		{
			method: "PUT",
			headers: {
				accept: "application/json",
				"content-type": "application/json",
				authorization: basicAuthHeader(email, apiToken),
			},
			body: JSON.stringify(payload),
		},
		signal
	);

	return { dry_run: false, updated: true, issue_key: issueKey };
}

async function jiraAddCommentImpl(
	params: { issue_key: string; comment_text: string; confirm?: boolean },
	signal?: AbortSignal
) {
	const { email, apiToken } = requireEnv();
	const baseUrl = "https://smec.atlassian.net";
	const confirm = params.confirm === true;

	const issueKey = params.issue_key;
	if (!issueKey?.trim()) throw new Error("issue_key is required");
	const commentText = String(params.comment_text ?? "").trim();
	if (!commentText) throw new Error("comment_text must not be empty");

	const payload = { body: adfFromPlainText(commentText) };

	if (!confirm) {
		return {
			dry_run: true,
			request: {
				method: "POST",
				url: `${baseUrl}/rest/api/3/issue/${issueKey}/comment`,
				body: payload,
			},
		};
	}

	const url = `${baseUrl}/rest/api/3/issue/${encodeURIComponent(issueKey)}/comment`;
	const data = await fetchJson(
		url,
		{
			method: "POST",
			headers: {
				accept: "application/json",
				"content-type": "application/json",
				authorization: basicAuthHeader(email, apiToken),
			},
			body: JSON.stringify(payload),
		},
		signal
	);

	return { dry_run: false, created: true, issue_key: issueKey, comment_id: data?.id ?? null };
}

export default function atlassianWriterExtension(pi: ExtensionAPI) {
	pi.registerTool({
		name: "jira_update_issue",
		label: "Jira: update issue (summary/description)",
		description:
			"Update an existing Jira issue (summary/title and/or description). Default is dry-run; set confirm=true to execute.",
		parameters: Type.Object({
			issue_key: Type.String({ description: "Jira issue key (e.g. PD-7278)" }),
			summary: Type.Optional(Type.String({ description: "New summary/title" })),
			description_text: Type.Optional(Type.String({ description: "New description text (plain text)." })),
			description_mode: Type.Optional(
				Type.Union([
					Type.Literal("overwrite"),
					Type.Literal("append"),
				], {
					description: "How to apply description_text (default: overwrite)",
				})
			),
			confirm: Type.Optional(
				Type.Boolean({
					description: "Set true to execute the write",
				})
			),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			try {
				const res = await jiraUpdateIssueImpl(params, signal);
				return { content: [{ type: "text", text: JSON.stringify(res, null, 2) }], details: {} };
			} catch (e: any) {
				log(ctx, "ERROR", "jira_update_issue failed", String(e?.message ?? e));
				throw e;
			}
		},
	});

	pi.registerTool({
		name: "jira_add_comment",
		label: "Jira: add comment",
		description:
			"Add a comment to an existing Jira issue. Default is dry-run; set confirm=true to execute.",
		parameters: Type.Object({
			issue_key: Type.String({ description: "Jira issue key (e.g. PD-7278)" }),
			comment_text: Type.String({ description: "Comment text (plain text)." }),
			confirm: Type.Optional(
				Type.Boolean({
					description: "Set true to execute the write",
				})
			),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			try {
				const res = await jiraAddCommentImpl(params, signal);
				return { content: [{ type: "text", text: JSON.stringify(res, null, 2) }], details: {} };
			} catch (e: any) {
				log(ctx, "ERROR", "jira_add_comment failed", String(e?.message ?? e));
				throw e;
			}
		},
	});
}
