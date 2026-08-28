import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const DEFAULT_BUDGET = 100;
const MIN_BUDGET = 1;
const MAX_BUDGET = 100;
const DEFAULT_REPAIR_PROVIDER = "google";
const DEFAULT_REPAIR_MODEL = "gemini-3.7-flash";

export interface RepairMessage {
  role: string;
  content?: unknown;
}

export interface RepairEntry {
  id: string;
  timestamp: string;
  type: string;
  message?: RepairMessage;
  customType?: string;
  content?: unknown;
}

export interface Selection {
  entries: RepairEntry[];
  selectionRule: string;
  compactionRelation: string;
  availableUserTurns: number;
  omittedEarlierUserTurns: boolean;
  omittedPriorRepairs: number;
  omittedNonConversation: number;
}

export const HEADINGS = [
  "## Current direction",
  "## Agent's reading",
  "## Mismatch or correction",
  "## Established together",
  "## Still open",
] as const;

function isRepair(entry: RepairEntry): boolean {
  return entry.type === "custom_message" && entry.customType === "shared-attention-repair";
}

function isConversation(entry: RepairEntry): boolean {
  return entry.type === "message";
}

function visibleText(content: unknown): string[] {
  if (typeof content === "string") return [content];
  if (!Array.isArray(content)) return [];
  return content.flatMap((part) => {
    if (!part || typeof part !== "object") return [];
    const block = part as {
      type?: unknown;
      text?: unknown;
      content?: unknown;
    };
    if (block.type === "text" && typeof block.text === "string") return [block.text];
    if (block.type === "toolResult") return visibleText(block.content);
    return [];
  });
}

function entryText(entry: RepairEntry, includeToolEvents = true): string {
  if (entry.type === "custom_message") return visibleText(entry.content).join("\n");
  const content = entry.message?.content;
  if (!Array.isArray(content)) return visibleText(content).join("\n");
  return content.flatMap((part) => {
    if (!part || typeof part !== "object") return [];
    const block = part as {
      type?: unknown;
      text?: unknown;
      name?: unknown;
      arguments?: unknown;
      content?: unknown;
    };
    if (block.type === "text" && typeof block.text === "string") return [block.text];
    if (block.type === "toolCall" && typeof block.name === "string") {
      return includeToolEvents
        ? [`Tool call: ${block.name} (arguments omitted; inspect [#${entry.id}] if needed)`]
        : [];
    }
    if (block.type === "toolResult") {
      if (!includeToolEvents) return [];
      const visibleCharacters = visibleText(block.content).join("\n").length;
      return [`Tool result: ${visibleCharacters} visible characters omitted; inspect [#${entry.id}] if needed`];
    }
    return [];
  }).join("\n");
}

export function selectEpisode(branch: RepairEntry[], requestedBudget: number): Selection {
  const latestCompaction = branch
    .map((entry, index) => ({ entry, index }))
    .filter(({ entry }) => entry.type === "compaction")
    .at(-1);
  const messages = branch.filter(isConversation);
  const preamble: RepairEntry[] = [];
  const turns: RepairEntry[][] = [];
  for (const entry of messages) {
    if (entry.message?.role === "user") {
      turns.push([...(turns.length === 0 ? preamble : []), entry]);
    } else if (turns.length > 0) {
      turns.at(-1)!.push(entry);
    } else {
      preamble.push(entry);
    }
  }
  const budget = Math.max(1, Math.trunc(requestedBudget));
  const selectedTurns = turns.slice(-budget);
  const entries = selectedTurns.flat();
  const firstIndex = entries.length === 0 ? -1 : branch.indexOf(entries[0]);
  const lastIndex = entries.length === 0 ? -1 : branch.indexOf(entries.at(-1)!);
  const compactionRelation = !latestCompaction
    ? "no compaction in branch"
    : latestCompaction.index < firstIndex
      ? `latest compaction ${latestCompaction.entry.id} is before selected range`
      : latestCompaction.index > lastIndex
        ? `latest compaction ${latestCompaction.entry.id} is after selected range`
        : `selected range crosses latest compaction ${latestCompaction.entry.id}`;
  return {
    entries,
    selectionRule: "latest complete user-to-user turns; whole message entries retained across compaction boundaries",
    compactionRelation,
    availableUserTurns: turns.length,
    omittedEarlierUserTurns: turns.length > selectedTurns.length,
    omittedPriorRepairs: branch.filter(isRepair).length,
    omittedNonConversation: branch.filter((entry) => !isConversation(entry) && !isRepair(entry)).length,
  };
}

export function serializeEpisode(entries: RepairEntry[]): string {
  return entries.map((entry) => {
    const role = entry.type === "custom_message" ? "custom" : entry.message?.role ?? "unknown";
    const text = entryText(entry).trim();
    return `[#${entry.id}] timestamp=${entry.timestamp} role=${role} type=${entry.type}\n${text}`;
  }).join("\n\n");
}

function serializeContextBlock(
  heading: string,
  entries: RepairEntry[],
  includeToolEvents: boolean,
): string {
  const body = entries.map((entry) => {
    const role = entry.message?.role ?? "unknown";
    return `[#${entry.id}] timestamp=${entry.timestamp} role=${role}\n${entryText(entry, includeToolEvents).trim()}`;
  }).join("\n\n");
  return `${heading}\n${body || "- None in inspected span."}`;
}

export function serializeRepairContext(entries: RepairEntry[]): string {
  const userEntries = entries.filter((entry) => entry.type === "message" && entry.message?.role === "user");
  const assistantEntries = entries.filter((entry) => entry.type === "message" && entry.message?.role === "assistant");
  const toolEntries = entries.filter((entry) => entry.type === "message" && entry.message?.role === "toolResult");
  return [
    serializeContextBlock("USER'S CURRENT DIRECTION", userEntries, false),
    serializeContextBlock("AGENT'S READING", assistantEntries, false),
    serializeContextBlock("OBSERVED WORK", toolEntries, true),
  ].join("\n\n");
}

export function buildProjectionPrompt(
  transcript: string,
  maxWords: number,
  omittedEarlierUserTurns = false,
): string {
  const rangeEdge = omittedEarlierUserTurns
    ? "Under ## Still open, add exactly: - Earlier conversation was not inspected."
    : "Do not add scope counts, timestamps, provider details, or other inspection metadata.";
  return `You repair shared attention between the human and agent. Produce a concise candidate view that lets them continue from the same conversational reality.

The inspected material is mechanically separated into USER'S CURRENT DIRECTION, AGENT'S READING, and OBSERVED WORK.

Start from USER'S CURRENT DIRECTION only: what the user is currently trying to have the agent understand, correct, stop, or do. The user's active request, correction, objection, or constraint is the primary anchor. If a recent user message corrects the agent's framing, make that correction the current subject. Never infer a human goal, requirement, decision, or correction from AGENT'S READING or OBSERVED WORK.

AGENT'S READING may show what the assistant says it understood, assumed, or reported. It is context, not accepted decisions or evidence that work succeeded. OBSERVED WORK records attempts and results; it may explain whether the user's direction remains unresolved, but cannot establish the user's goal, correction, or acceptance. Never upgrade a participant's statement into a world fact or shared agreement.

Use exactly these five headings, in this order. Under each heading use concise bullets. Write substantive bullets with User:, Assistant:, or Both: and exact [#entry-id] references. Use Both: only for explicit alignment in cited user and assistant entries.

- Current direction names the human's active need or corrective demand.
- Agent's reading states the relevant visible assistant understanding or assumption, not a world fact or accepted result.
- Mismatch or correction preserves material disagreement or changed framing without resolving it.
- Established together contains only explicit shared decisions or results the user explicitly accepted; an assistant report is not an established conclusion.
- Still open contains live concerns, questions, or tensions without an explicit resolution.

${rangeEdge}

Do not include failed commands, write boundaries, deployment, tests, or other execution mechanics unless the user explicitly made them the subject. Do not advise, review work, propose a plan, infer consensus, claim completeness, or claim anything beyond the inspected range. If a heading has no relevant material in the inspected span, use: - None in inspected span.

${HEADINGS.join("\n")}

Return at most ${maxWords} words. Do not add a sixth section.

<inspected-entries>
${transcript}
</inspected-entries>`;
}

export function resolveApiKey(
  authenticatedKey: string | undefined,
  providerKey: string | undefined,
  modelKey: string | undefined,
): string | undefined {
  if (modelKey === "none" || modelKey === "no-api-key-needed") return modelKey;
  return authenticatedKey ?? providerKey;
}

export function redactSecrets(input: string, enabled: boolean): string {
  if (!enabled) return input;
  return input
    .replace(/sk-[A-Za-z0-9_-]{16,}/g, "[REDACTED_API_KEY]")
    .replace(/AIza[0-9A-Za-z_-]{20,}/g, "[REDACTED_GOOGLE_API_KEY]")
    .replace(/(OPENAI_API_KEY|ANTHROPIC_API_KEY|GOOGLE_API_KEY|GEMINI_API_KEY)\s*=\s*[^\s]+/g, "$1=[REDACTED]");
}

function config() {
  const maxWords = Number.parseInt(
    process.env.PI_ATTENTION_REPAIR_MAX_WORDS ?? "300",
    10,
  );
  return {
    provider: process.env.PI_ATTENTION_REPAIR_PROVIDER?.trim() || DEFAULT_REPAIR_PROVIDER,
    model: process.env.PI_ATTENTION_REPAIR_MODEL?.trim() || DEFAULT_REPAIR_MODEL,
    egress: process.env.PI_ATTENTION_REPAIR_EGRESS?.trim() || "unknown",
    maxWords: Math.max(80, Math.min(600, Number.isFinite(maxWords) ? maxWords : 300)),
    redact: !["0", "false", "no", "off"].includes(
      (process.env.PI_ATTENTION_REPAIR_REDACT ?? "true").toLowerCase(),
    ),
  };
}

export function selectionStatus(selection: Selection): string {
  const turns = selection.omittedEarlierUserTurns
    ? selection.entries.filter((entry) => entry.message?.role === "user").length
    : selection.availableUserTurns;
  const label = `${turns} user turn${turns === 1 ? "" : "s"}`;
  return selection.omittedEarlierUserTurns
    ? `Repairing the last ${label}...`
    : `Repairing the current session (${label})...`;
}

function completionText(response: { content: unknown }): string {
  if (!Array.isArray(response.content)) return "";
  return response.content
    .filter(
      (part): part is { type: "text"; text: string } =>
        typeof part === "object" &&
        part !== null &&
        (part as { type?: unknown }).type === "text" &&
        typeof (part as { text?: unknown }).text === "string",
    )
    .map((part) => part.text)
    .join("\n")
    .trim();
}

function completionStatus(response: { usage?: unknown }): string {
  const usage = response.usage as { input?: unknown; output?: unknown } | undefined;
  if (typeof usage?.input !== "number" || typeof usage.output !== "number") {
    return "Shared attention repaired · token usage unavailable.";
  }
  return `Shared attention repaired · ${usage.input.toLocaleString()} input · ${usage.output.toLocaleString()} output tokens`;
}

export default function sharedAttentionRepair(pi: ExtensionAPI) {
  pi.registerCommand("attention-repair", {
    description: "Publish a bounded candidate projection (1–100 complete user turns; default 100)",
    handler: async (args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("attention-repair requires the TUI.", "error");
        return;
      }
      const suppliedBudget = args.trim();
      if (suppliedBudget && !/^\d+$/.test(suppliedBudget)) {
        ctx.ui.notify(`Budget must be an integer from ${MIN_BUDGET} to ${MAX_BUDGET}.`, "error");
        return;
      }
      const budget = suppliedBudget ? Number(suppliedBudget) : DEFAULT_BUDGET;
      if (budget < MIN_BUDGET || budget > MAX_BUDGET) {
        ctx.ui.notify(`Budget must be an integer from ${MIN_BUDGET} to ${MAX_BUDGET}.`, "error");
        return;
      }
      const cfg = config();
      ctx.ui.notify("Preparing shared attention repair...", "info");
      await ctx.waitForIdle();
      const selected = selectEpisode(
        ctx.sessionManager.getBranch() as unknown as RepairEntry[],
        budget,
      );
      if (!selected.entries.length) {
        ctx.ui.notify("No complete user turns to inspect.", "warning");
        return;
      }
      ctx.ui.notify(selectionStatus(selected), "info");
      const first = selected.entries[0];
      const last = selected.entries.at(-1)!;
      const sessionId = ctx.sessionManager.getSessionId?.() ?? "unknown";
      const leafId = ctx.sessionManager.getLeafId?.() ?? "unknown";
      const generatedAt = new Date().toISOString();
      const repairContext = redactSecrets(serializeRepairContext(selected.entries), cfg.redact);
      const model = ctx.modelRegistry.find(cfg.provider, cfg.model);
      if (!model) {
        ctx.ui.notify(`Configured repair model not found: ${cfg.provider}/${cfg.model}.`, "error");
        return;
      }
      const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
      const providerKey = await ctx.modelRegistry.getApiKeyForProvider(cfg.provider);
      const modelKey = (model as unknown as { apiKey?: string }).apiKey;
      const apiKey = resolveApiKey(auth.ok ? auth.apiKey : undefined, providerKey, modelKey);
      if (!apiKey) {
        ctx.ui.notify(
          `Configured repair model authentication unavailable: ${auth.ok ? "no API key" : auth.error}.`,
          "error",
        );
        return;
      }

      try {
        const response = await ctx.modelRegistry.complete(
          model,
          {
            messages: [{
              role: "user",
              content: [{ type: "text", text: buildProjectionPrompt(
                repairContext,
                cfg.maxWords,
                selected.omittedEarlierUserTurns,
              ) }],
              timestamp: Date.now(),
            }],
          },
          { apiKey, headers: auth.ok ? auth.headers : undefined, cacheRetention: "none" },
        );
        const projection = completionText(response);
        if (!projection) {
          ctx.ui.notify("Attention repair returned no text. Nothing was published.", "warning");
          return;
        }
        pi.sendMessage(
          {
            customType: "shared-attention-repair",
            display: true,
            content: projection,
            details: {
              sessionId,
              leafId,
              range: {
                firstId: first.id,
                firstTimestamp: first.timestamp,
                lastId: last.id,
                lastTimestamp: last.timestamp,
              },
              generatedAt,
              provider: cfg.provider,
              model: cfg.model,
              budget,
              selection: selected.selectionRule,
              compactionRelation: selected.compactionRelation,
              egress: cfg.egress,
              omissions: {
                earlierUserTurns: selected.omittedEarlierUserTurns,
                priorRepairCards: selected.omittedPriorRepairs,
                nonConversationEntries: selected.omittedNonConversation,
              },
              usage: response.usage,
            },
          },
          { triggerTurn: false },
        );
        ctx.ui.notify(completionStatus(response), "info");
      } catch (error) {
        const detail = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`Attention repair completion failed: ${detail}. Nothing was published.`, "error");
      }
    },
  });
}
