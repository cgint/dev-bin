import { streamSimple, type AssistantMessage, type Message, type SimpleStreamOptions, type Usage } from "@mariozechner/pi-ai";
import {
	BorderedLoader,
	convertToLlm,
	type ExtensionAPI,
	type ExtensionCommandContext,
	type SessionEntry,
} from "@mariozechner/pi-coding-agent";
import { Box, Text } from "@mariozechner/pi-tui";

const CUSTOM_TYPE = "btw";

type StoredBtwEntry = {
	question: string;
	answer: string;
	provider: string;
	model: string;
	thinkingLevel: "off" | "minimal" | "low" | "medium" | "high" | "xhigh";
	stopReason: AssistantMessage["stopReason"];
	usage: Usage;
	askedAt: number;
	contextMessageCount: number;
};

type BtwResult =
	| { kind: "ok"; entry: StoredBtwEntry }
	| { kind: "cancelled" }
	| { kind: "error"; message: string };

function extractText(message: AssistantMessage): string {
	return message.content
		.filter((content): content is { type: "text"; text: string } => content.type === "text")
		.map((content) => content.text)
		.join("\n")
		.trim();
}

function toPreview(text: string, max = 120): string {
	const singleLine = text.replace(/\s+/g, " ").trim();
	if (!singleLine) return "(empty response)";
	return singleLine.length <= max ? singleLine : `${singleLine.slice(0, max - 1)}…`;
}

async function askBtwQuestion(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	question: string,
	signal?: AbortSignal,
): Promise<StoredBtwEntry> {
	if (!ctx.model) {
		throw new Error("No active model selected");
	}

	const apiKey = await ctx.modelRegistry.getApiKey(ctx.model);
	if (!apiKey) {
		throw new Error(`No API key available for ${ctx.model.provider}/${ctx.model.id}`);
	}

	const branch = ctx.sessionManager.getBranch();
	const messages = branch
		.filter((entry): entry is SessionEntry & { type: "message" } => entry.type === "message")
		.map((entry) => entry.message);
	const llmMessages = convertToLlm(messages);
	const askedAt = Date.now();
	const thinkingLevel = pi.getThinkingLevel();
	const options: SimpleStreamOptions = {
		apiKey,
		signal,
	};

	if (thinkingLevel !== "off") {
		options.reasoning = thinkingLevel;
	}

	const questionMessage: Message = {
		role: "user",
		content: [{ type: "text", text: question }],
		timestamp: askedAt,
	};

	const stream = streamSimple(
		ctx.model,
		{
			systemPrompt: ctx.getSystemPrompt(),
			messages: [...llmMessages, questionMessage],
		},
		options,
	);

	let streamedText = "";
	for await (const event of stream) {
		if (event.type === "text_delta") streamedText += event.delta;
		if (event.type === "text_end" && !streamedText) streamedText += event.content;
	}

	const response = await stream.result();
	const answer = extractText(response) || streamedText.trim();

	return {
		question,
		answer,
		provider: ctx.model.provider,
		model: ctx.model.id,
		thinkingLevel,
		stopReason: response.stopReason,
		usage: response.usage,
		askedAt,
		contextMessageCount: llmMessages.length,
	};
}

export default function btw(pi: ExtensionAPI) {
	pi.on("context", async (event) => ({
		messages: event.messages.filter(
			(message) => !(message.role === "custom" && message.customType === CUSTOM_TYPE),
		),
	}));

	pi.registerMessageRenderer(CUSTOM_TYPE, (message, { expanded }, theme) => {
		const details = message.details as StoredBtwEntry | undefined;
		const question = details?.question?.trim() || "(missing question)";
		const answer = typeof message.content === "string" ? message.content : "";
		const meta = details
			? `${details.provider}/${details.model} · thinking ${details.thinkingLevel}`
			: "one-off side question";

		let text = theme.fg("accent", theme.bold("BTW"));
		text += ` ${theme.fg("muted", question)}`;
		text += `\n${theme.fg("dim", meta)}`;

		if (expanded) {
			text += `\n\n${answer || theme.fg("dim", "(empty response)")}`;
		} else {
			text += `\n${theme.fg("text", toPreview(answer, 180))}`;
			text += `\n${theme.fg("dim", "Ctrl+O to expand")}`;
		}

		const box = new Box(1, 1, (t) => theme.bg("customMessageBg", t));
		box.addChild(new Text(text, 0, 0));
		return box;
	});

	pi.registerCommand("btw", {
		description: "Ask a one-off side question using the current branch context",
		handler: async (args, ctx) => {
			const question = args.trim();
			if (!question) {
				ctx.ui.notify("Usage: /btw <question>", "warning");
				return;
			}

			if (!ctx.model) {
				ctx.ui.notify("No active model selected", "error");
				return;
			}

			if (!ctx.isIdle()) {
				ctx.ui.notify("Wait for the current agent turn to finish before using /btw", "warning");
				return;
			}

			let result: BtwResult;
			if (ctx.hasUI) {
				result = await ctx.ui.custom<BtwResult>((tui, theme, _kb, done) => {
					const loader = new BorderedLoader(tui, theme, `BTW: asking ${ctx.model!.id}...`);
					loader.onAbort = () => done({ kind: "cancelled" });

					askBtwQuestion(pi, ctx, question, loader.signal)
						.then((entry) => done({ kind: "ok", entry }))
						.catch((error: unknown) => {
							done({
								kind: "error",
								message: error instanceof Error ? error.message : String(error),
							});
						});

					return loader;
				});
			} else {
				try {
					result = { kind: "ok", entry: await askBtwQuestion(pi, ctx, question) };
				} catch (error) {
					result = {
						kind: "error",
						message: error instanceof Error ? error.message : String(error),
					};
				}
			}

			if (result.kind === "cancelled") {
				ctx.ui.notify("BTW cancelled", "info");
				return;
			}

			if (result.kind === "error") {
				ctx.ui.notify(`BTW failed: ${result.message}`, "error");
				return;
			}

			pi.appendEntry(CUSTOM_TYPE, result.entry);
			pi.sendMessage({
				customType: CUSTOM_TYPE,
				content: result.entry.answer,
				display: true,
				details: result.entry,
			});

			const level = result.entry.stopReason === "stop" ? "success" : "warning";
			ctx.ui.notify(`BTW saved (${result.entry.model})`, level);
		},
	});
}
