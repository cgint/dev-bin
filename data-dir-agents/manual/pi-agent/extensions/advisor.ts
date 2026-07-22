/**
 * Pi Advisor Extension
 *
 * Drop this file into:
 *   .pi/extensions/advisor.ts
 * or:
 *   ~/.pi/agent/extensions/advisor.ts
 *
 * Sends the current Pi transcript to a stronger advisor model and returns
 * strategic guidance. The advisor does not call tools, edit files, or write
 * the final user-facing answer.
 *
 * Recommended env for a local executor:
 *   export PI_ADVISOR_PROVIDER=openai-codex
 *   export PI_ADVISOR_MODEL=gemini-3.6-flash
 *
 * Alternatively, configure a fallback chain (tries left-to-right on error):
 *   export PI_ADVISOR_MODELS="provider/model:effort#provider2/model2:effort2"
 *   # Example: try local qwen first, fall back to Gemini:
 *   export PI_ADVISOR_MODELS="8081-twins/qwen36-27b-nvidia-nvfp4:off#google/gemini-3.6-flash:medium"
 *
 * When PI_ADVISOR_MODELS is set, PI_ADVISOR_PROVIDER / PI_ADVISOR_MODEL are
 * ignored (backward compat: unset PI_ADVISOR_MODELS to use the old behavior).
 *
 * Optional privacy gate:
 *   export PI_ADVISOR_REQUIRE_ALLOW=1
 *   export PI_ADVISOR_ALLOWED=1
 *
 * Optional tuning:
 *   PI_ADVISOR_MAX_PER_TURN=2
 *   PI_ADVISOR_MAX_WORDS=600
 *   PI_ADVISOR_REASONING_EFFORT=high
 *   PI_ADVISOR_REDACT=1
 *   PI_ADVISOR_CACHE=short   # "none" | "short" | "long"
 *
 * Disable entirely: set PI_ADVISOR_MODE=off.
 *
 * Env is read lazily: change a variable and call /reload (no process restart
 * needed) to pick up the new value.
 */

import { randomUUID } from "node:crypto";
import { complete, StringEnum, type CacheRetention } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  convertToLlm,
  serializeConversation,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const TOOL_NAME = "advisor";
const ADVISOR_CUSTOM_MESSAGE_TYPE = "advisor-advice";

// Stable id for this extension instance. Used as a fallback cache-affinity
// hint when the session manager does not expose a session id.
const FALLBACK_SESSION_ID = `advisor-ext-${randomUUID()}`;

type AdvisorStage =
  | "orientation"
  | "approach"
  | "stuck"
  | "final_review"
  | "manual";

type AdvisorParams = {
  stage?: AdvisorStage;
  question?: string;
  max_words?: number;
  context?: string;
  include_transcript?: boolean;
};

type AdvisorRunResult = {
  ok: boolean;
  text: string;
  provider: string;
  model: string;
  promptChars: number;
  transcriptChars: number;
  callIndex: number;
  turnCallIndex: number;
  error?: string;
  attemptLines?: string[];
};

/** One entry in the advisor fallback chain. */
interface AdvisorAttempt {
  provider: string;
  model: string;
  /** Reasoning effort override. Empty string means "use config default". */
  reasoningEffort: string;
}

// Minimal shape for session branch entries we actually read.
interface BranchMessage {
  role?: string;
  toolName?: string;
  content?: unknown;
  details?: {
    advisor?: {
      callIndex?: unknown;
    };
  };
  customType?: string;
}

interface BranchEntry {
  type?: string;
  message?: BranchMessage;
}

function env(name: string, fallback = ""): string {
  const value = process.env[name];
  return value === undefined || value === "" ? fallback : value;
}

function intEnv(name: string, fallback: number): number {
  const raw = env(name);
  if (!raw) return fallback;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : fallback;
}

function boolEnv(name: string, fallback = false): boolean {
  const raw = env(name);
  if (!raw) return fallback;
  return ["1", "true", "yes", "y", "on"].includes(raw.toLowerCase());
}

function isOffMode(): boolean {
  const mode = env("PI_ADVISOR_MODE", "").trim().toLowerCase();
  return ["off", "false", "0", "disabled", "disable"].includes(mode);
}

/**
 * Runtime config resolved on each call. Lets users change env vars and
 * /reload without restarting the process.
 */
interface AdvisorConfig {
  provider: string;
  model: string;
  requireAllow: boolean;
  allowed: boolean;
  redact: boolean;
  maxPerTurn: number;
  defaultMaxWords: number;
  reasoningEffort: string;
  cacheRetention: CacheRetention;
}

function getConfig(): AdvisorConfig {
  const requireAllow = boolEnv("PI_ADVISOR_REQUIRE_ALLOW", false);
  const cacheRaw = env("PI_ADVISOR_CACHE", "short").toLowerCase();
  const cacheRetention: CacheRetention =
    cacheRaw === "none" || cacheRaw === "long" ? cacheRaw : "short";

  return {
    provider: env("PI_ADVISOR_PROVIDER", "google"),
    model: env("PI_ADVISOR_MODEL", "gemini-3.6-flash"),
    requireAllow,
    allowed: boolEnv("PI_ADVISOR_ALLOWED", !requireAllow),
    redact: boolEnv("PI_ADVISOR_REDACT", true),
    maxPerTurn: intEnv("PI_ADVISOR_MAX_PER_TURN", 10),
    defaultMaxWords: intEnv("PI_ADVISOR_MAX_WORDS", 600),
    reasoningEffort: env("PI_ADVISOR_REASONING_EFFORT", "medium"),
    cacheRetention,
  };
}

function clampWords(value: unknown, fallback: number): number {
  const n =
    typeof value === "number" && Number.isFinite(value) ? value : fallback;
  return Math.max(80, Math.min(Math.trunc(n), 1_200));
}

// ---------------------------------------------------------------------------
// Model chain resolution
// ---------------------------------------------------------------------------

/**
 * Parse one entry from PI_ADVISOR_MODELS.
 *
 * Format:  provider/model[:reasoningEffort]
 *
 * - Split on the **first** "/" → provider / rest
 * - Split rest on the **last** ":" → model / effort (effort may be absent)
 */
function parseAdvisorEntry(raw: string, defaultEffort: string): AdvisorAttempt | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;

  // Split on first "/" to get provider.
  const slashIdx = trimmed.indexOf("/");
  if (slashIdx < 1) return null; // need at least "x/y"

  const provider = trimmed.slice(0, slashIdx);
  const rest = trimmed.slice(slashIdx + 1);
  if (!rest) return null;

  // Split on last ":" to get model + optional effort.
  const colonIdx = rest.lastIndexOf(":");
  let model: string;
  let reasoningEffort: string;

  if (colonIdx > 0) {
    model = rest.slice(0, colonIdx);
    reasoningEffort = rest.slice(colonIdx + 1).trim();
  } else {
    model = rest;
    reasoningEffort = "";
  }

  return {
    provider,
    model,
    reasoningEffort: reasoningEffort || defaultEffort,
  };
}

/**
 * Resolve the advisor model chain.
 *
 * Priority:
 * 1. If PI_ADVISOR_MODELS is set → parse it (#-separated entries).
 * 2. Otherwise → single entry from PI_ADVISOR_PROVIDER / PI_ADVISOR_MODEL.
 */
function resolveAdvisorChain(cfg: AdvisorConfig): AdvisorAttempt[] {
  const chainRaw = env("PI_ADVISOR_MODELS", "").trim();

  // --- Fast path: no chain configured → use built-in default chain ---
  if (!chainRaw) {
    const defaultChain = "8081-twins/qwen36-27b-nvidia-nvfp4:off#google/gemini-3.6-flash:medium";
    const attempts: AdvisorAttempt[] = defaultChain
      .split("#")
      .map((raw) => parseAdvisorEntry(raw, ""))
      .filter((e): e is AdvisorAttempt => e !== null);
    return attempts;
  }

  // --- Parse the chain ---
  const entries = chainRaw.split("#").map((raw) => parseAdvisorEntry(raw, ""));
  const attempts: AdvisorAttempt[] = [];

  for (const entry of entries) {
    if (entry) {
      // Fill in per-entry effort: entry's own value > config default > empty
      if (!entry.reasoningEffort) {
        entry.reasoningEffort = cfg.reasoningEffort;
      }
      attempts.push(entry);
    }
  }

  // If parsing produced nothing, fall back to legacy single model.
  if (attempts.length === 0) {
    return [
      {
        provider: cfg.provider,
        model: cfg.model,
        reasoningEffort: cfg.reasoningEffort,
      },
    ];
  }

  return attempts;
}

function redactSecrets(input: string, enabled: boolean): string {
  if (!enabled) return input;

  return (
    input
      // Known-prefix provider keys (specific → generic).
      .replace(/sk-ant-[A-Za-z0-9_-]{16,}/g, "[REDACTED_ANTHROPIC_KEY]")
      .replace(/sk-proj-[A-Za-z0-9_-]{16,}/g, "[REDACTED_OPENAI_PROJECT_KEY]")
      // Tight fallback for other OpenAI-style keys: require a word boundary and
      // long alnum tail (no dashes/underscores) so we don't eat identifiers
      // like "sk-learn" or "sk-my-branch-name".
      .replace(/\bsk-[A-Za-z0-9]{32,}\b/g, "[REDACTED_API_KEY]")
      .replace(/AIza[0-9A-Za-z_-]{20,}/g, "[REDACTED_GOOGLE_API_KEY]")
      .replace(/ghp_[0-9A-Za-z_]{20,}/g, "[REDACTED_GITHUB_TOKEN]")
      .replace(/github_pat_[0-9A-Za-z_]{20,}/g, "[REDACTED_GITHUB_TOKEN]")
      .replace(/xox[baprs]-[0-9A-Za-z-]{20,}/g, "[REDACTED_SLACK_TOKEN]")
      .replace(
        /(OPENAI_API_KEY|ANTHROPIC_API_KEY|GOOGLE_API_KEY|GEMINI_API_KEY|GITHUB_TOKEN|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN)\s*=\s*["']?[^"'\s]+["']?/g,
        "$1=[REDACTED]",
      )
      .replace(
        /Authorization:\s*Bearer\s+[^\s"'`]+/gi,
        "Authorization: Bearer [REDACTED]",
      )
      .replace(
        /-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/g,
        "[REDACTED_PRIVATE_KEY]",
      )
  );
}

function contentToText(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";

  const parts: string[] = [];

  for (const part of content) {
    if (!part || typeof part !== "object") continue;
    const block = part as {
      type?: string;
      text?: string;
      name?: string;
      arguments?: unknown;
      content?: unknown;
    };

    if (block.type === "text" && typeof block.text === "string") {
      parts.push(block.text);
    } else if (block.type === "toolCall" && typeof block.name === "string") {
      parts.push(
        `Tool call: ${block.name} ${JSON.stringify(block.arguments ?? {})}`,
      );
    } else if (typeof block.text === "string") {
      parts.push(block.text);
    } else if (block.content) {
      const nested = contentToText(block.content);
      if (nested) parts.push(nested);
    }
  }

  return parts.join("\n");
}

function fallbackSerializeBranch(entries: BranchEntry[]): string {
  const sections: string[] = [];

  for (const entry of entries) {
    if (entry?.type !== "message" || !entry.message) continue;

    const role = entry.message.role ?? "unknown";
    const text = contentToText(entry.message.content).trim();
    const toolName = entry.message.toolName ? ` ${entry.message.toolName}` : "";

    if (text) {
      sections.push(`${role}${toolName}:\n${text}`);
    }
  }

  return sections.join("\n\n");
}

function getBranchEntries(
  ctx: ExtensionContext | ExtensionCommandContext,
): BranchEntry[] {
  return (ctx.sessionManager.getBranch?.() ?? []) as BranchEntry[];
}

function getBranchMessages(
  ctx: ExtensionContext | ExtensionCommandContext,
): BranchMessage[] {
  return getBranchEntries(ctx)
    .filter((entry) => entry?.type === "message" && entry.message)
    .map((entry) => entry.message as BranchMessage);
}

function buildTranscript(
  ctx: ExtensionContext | ExtensionCommandContext,
  redact: boolean,
): string {
  let serialized = "";

  try {
    // convertToLlm expects pi's internal message shape; our BranchMessage is
    // a read-only subset, so a structural cast is safe here.
    serialized = serializeConversation(
      convertToLlm(getBranchMessages(ctx) as never),
    );
  } catch {
    serialized = fallbackSerializeBranch(getBranchEntries(ctx));
  }

  return redactSecrets(serialized, redact);
}

function activeToolSummary(pi: ExtensionAPI): string {
  // getActiveTools() returns an array of tool name strings.
  const tools = pi
    .getActiveTools()
    .filter((name) => name !== TOOL_NAME)
    .map((name) => `- ${name}`)
    .join("\n");

  return tools || "- No active non-advisor tools detected.";
}

function executorName(ctx: ExtensionContext | ExtensionCommandContext): string {
  const model = (ctx as unknown as { model?: { provider?: string; id?: string; name?: string } }).model;
  if (!model) return "unknown";
  return `${model.provider ?? "unknown"}/${model.id ?? model.name ?? "unknown"}`;
}

function getSessionIdForCache(
  ctx: ExtensionContext | ExtensionCommandContext,
): string {
  try {
    const sid = ctx.sessionManager.getSessionId?.();
    if (typeof sid === "string" && sid.length > 0) return sid;
  } catch {
    // fall through
  }
  return FALLBACK_SESSION_ID;
}

function buildAdvisorPrompt(
  pi: ExtensionAPI,
  ctx: ExtensionContext | ExtensionCommandContext,
  params: AdvisorParams,
  transcript: string,
  cfg: AdvisorConfig,
): string {
  const stage = params.stage ?? "approach";
  const question =
    params.question?.trim() ||
    "Review the current task state and advise the executor on the best next steps.";
  const maxWords = clampWords(params.max_words, cfg.defaultMaxWords);
  const includeTranscript = params.include_transcript !== false;
  const curatedContext = redactSecrets(
    (params.context ?? "").trim(),
    cfg.redact,
  );

  let systemPrompt = "";
  try {
    systemPrompt =
      (ctx as unknown as { getSystemPrompt?: () => string }).getSystemPrompt?.() ?? "";
  } catch {
    systemPrompt = "";
  }
  systemPrompt = redactSecrets(systemPrompt, cfg.redact);

  const cwd =
    (ctx as unknown as { cwd?: string }).cwd ?? "(unknown)";

  const contextSection = curatedContext
    ? `\n\nThe executor selected the following as most relevant. Treat it as primary signal; the conversation transcript (if present) is supporting context.\n<executor_curated_context>\n${curatedContext}\n</executor_curated_context>`
    : "";

  const transcriptSection = includeTranscript
    ? `\n\nConversation transcript:\n<conversation>\n${transcript}\n</conversation>`
    : "";

  return `
You are the ADVISOR model for a Pi coding-agent session.

The executor is: ${executorName(ctx)}.
The executor may be a smaller local model. You are not the executor.
You do not call tools, edit files, run commands, or write the final user-facing answer.
Your job is to give strategic guidance that the executor can apply with its own tools.

Current working directory:
${cwd}

Executor tools available:
${activeToolSummary(pi)}

Advisor request stage:
${stage}

Executor's specific question:
${question}

Rules:
- Base your advice on the transcript. Do not invent files, APIs, test results, or requirements.
- Be concrete: name files, functions, commands, and tests only when the transcript supports them.
- Prefer minimal, reversible changes and verification over speculative rewrites.
- If the executor is stuck, diagnose the likely failure pattern and propose a different next step.
- If this is final_review, identify missing verification and whether it is safe to declare done.
- If evidence conflicts with your preferred plan, call out the conflict explicitly.
- Keep the response under ${maxWords} words.
- Use exactly this structure:

1. Situation
2. Recommended plan
3. Risks / things to verify
4. Done criteria or stop signal

Pi system prompt excerpt:
<system_prompt>
${systemPrompt}
</system_prompt>${contextSection}${transcriptSection}
`.trim();
}

interface CompletionInfo {
  text: string;
  stopReason?: string;
  errorMessage?: string;
  outputTokens?: number;
  reasoningTokens?: number;
}

function summarizeCompletion(response: unknown): CompletionInfo {
  const r = response as
    | {
        content?: unknown;
        stopReason?: string;
        errorMessage?: string;
        usage?: { output?: number; reasoning?: number };
      }
    | undefined;

  const content = Array.isArray(r?.content) ? r!.content : [];

  const text = content
    .filter(
      (part: unknown): part is { type: string; text: string } =>
        typeof part === "object" &&
        part !== null &&
        (part as { type?: unknown }).type === "text" &&
        typeof (part as { text?: unknown }).text === "string",
    )
    .map((part) => part.text)
    .join("\n")
    .trim();

  return {
    text,
    stopReason: r?.stopReason,
    errorMessage: r?.errorMessage,
    outputTokens: r?.usage?.output,
    reasoningTokens: r?.usage?.reasoning,
  };
}

const ADVISOR_GUIDANCE_TEXT = `
Advisor tool guidance:
You have an \`advisor\` tool backed by a stronger external model.

Call advisor when:
- You have completed initial orientation reads on a complex task, but before committing to a non-trivial implementation approach.
- You are stuck after repeated command/test failures, contradictory evidence, or non-converging edits.
- You are considering a major change of approach.
- You believe a complex task is complete and want final review before declaring done.

Do not call advisor for simple one-step tasks or when the next action is obvious.
Do not use advisor as a substitute for reading the relevant files or running tests.
Treat advisor advice as strategic guidance, not ground truth. If local evidence conflicts with the advice, investigate and reconcile the conflict explicitly.
`.trim();

export default function advisorExtension(pi: ExtensionAPI) {
  if (isOffMode()) {
    return;
  }

  let callsThisTurn = 0;
  let callsThisSession = 0;

  function readCallIndex(message: BranchMessage | undefined): number {
    const raw = message?.details?.advisor?.callIndex;
    if (typeof raw === "number" && Number.isFinite(raw) && raw > 0) {
      return Math.trunc(raw);
    }
    return 0;
  }

  function restoreAdvisorCount(
    ctx: ExtensionContext | ExtensionCommandContext,
  ) {
    callsThisTurn = 0;
    callsThisSession = 0;

    for (const entry of getBranchEntries(ctx)) {
      const message = entry?.message;
      if (entry?.type !== "message" || !message) continue;

      const isAdvisorToolResult =
        message.role === "toolResult" && message.toolName === TOOL_NAME;
      const isAdvisorCustom =
        message.role === "custom" &&
        message.customType === ADVISOR_CUSTOM_MESSAGE_TYPE;

      if (!isAdvisorToolResult && !isAdvisorCustom) continue;

      const n = readCallIndex(message);
      if (n > callsThisSession) {
        callsThisSession = n;
      }
    }
  }

  async function runAdvisor(
    ctx: ExtensionContext | ExtensionCommandContext,
    params: AdvisorParams,
    signal?: AbortSignal,
    onAttempt?: (attemptLines: string[], index: number, total: number, provider: string, model: string) => void,
  ): Promise<AdvisorRunResult> {
    const cfg = getConfig();

    const base = {
      promptChars: 0,
      transcriptChars: 0,
      callIndex: callsThisSession,
      turnCallIndex: callsThisTurn,
    };

    if (!cfg.allowed) {
      return {
        ...base,
        ok: false,
        text: "Advisor is disabled by privacy gate. Set PI_ADVISOR_ALLOWED=1, or unset PI_ADVISOR_REQUIRE_ALLOW, to allow sending transcript context to the advisor provider.",
        provider: "",
        model: "",
        error: "privacy_gate",
      };
    }

    if (callsThisTurn >= cfg.maxPerTurn) {
      return {
        ...base,
        ok: false,
        text: `Advisor per-turn cap reached (${cfg.maxPerTurn}). Continue with the best current plan unless the user explicitly asks for more advisor calls.`,
        provider: "",
        model: "",
        error: "per_turn_cap",
      };
    }

    const includeTranscript = params.include_transcript !== false;
    const hasContext = (params.context ?? "").trim().length > 0;

    if (!includeTranscript && !hasContext) {
      return {
        ...base,
        ok: false,
        text: "Advisor called with include_transcript=false but no `context` was provided. Either keep include_transcript at its default (true) or pass a non-empty `context` string with the curated information you want the advisor to consider.",
        provider: "",
        model: "",
        error: "missing_context",
      };
    }

    const transcript = includeTranscript ? buildTranscript(ctx, cfg.redact) : "";
    const prompt = buildAdvisorPrompt(pi, ctx, params, transcript, cfg);

    // Resolve the fallback chain (selection driven solely by env vars / defaults).
    const attempts = resolveAdvisorChain(cfg);

    // Increment counters once for the whole chain (counts as 1 call).
    callsThisTurn += 1;
    callsThisSession += 1;

    const lastErrors: string[] = [];
    let lastAttempt: { provider: string; model: string } | null = null;
    const attemptLines: string[] = [];

    const shortMessage = (message: string): string => {
      const compact = message.replace(/\s+/g, " ").trim();
      return compact.length > 50 ? `${compact.slice(0, 47)}...` : compact;
    };

    const setAttemptLine = (
      index: number,
      total: number,
      provider: string,
      model: string,
      line: string,
    ) => {
      attemptLines[index - 1] = line;
      onAttempt?.([...attemptLines], index, total, provider, model);
    };

    for (let i = 0; i < attempts.length; i++) {
      const attempt = attempts[i];
      const { provider, model: modelId, reasoningEffort } = attempt;
      lastAttempt = { provider, model: modelId };
      setAttemptLine(
        i + 1,
        attempts.length,
        provider,
        modelId,
        `Connecting to advisor ${provider}/${modelId}...`,
      );

      const model = ctx.modelRegistry.find(provider, modelId);
      if (!model) {
        const msg = "model not found";
        lastErrors.push(`[${provider}/${modelId}] ${msg}`);
        setAttemptLine(
          i + 1,
          attempts.length,
          provider,
          modelId,
          `Error seeking advice from advisor ${provider}/${modelId}!\n      -> ${shortMessage(msg)}`,
        );
        continue;
      }

      const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);

      // If auth fails but the provider declares no-api-key-needed, bypass the
      // gate — getApiKeyAndHeaders uses a stricter path than normal execution
      // and can reject providers that work fine at runtime.
      let authOk = auth.ok;
      if (!authOk) {
        const rawModel = ctx.modelRegistry.find(provider, modelId);
        const rawApiKey = (rawModel as unknown as { apiKey?: string })?.apiKey;
        if (rawApiKey === "no-api-key-needed") {
          authOk = true;
        }
      }

      if (!authOk) {
        const msg = `auth: ${auth.error}`;
        lastErrors.push(`[${provider}/${modelId}] ${msg}`);
        setAttemptLine(
          i + 1,
          attempts.length,
          provider,
          modelId,
          `Error seeking advice from advisor ${provider}/${modelId}!\n      -> ${shortMessage(msg)}`,
        );
        continue;
      }

      // Work around modelRegistry.getApiKeyAndHeaders() using a stricter auth
      // path than normal model execution for some env-key setups (for example
      // google/GEMINI_API_KEY). If the model-specific lookup yields no API key,
      // retry with provider-level resolution, which includes the standard env
      // fallback used elsewhere in Pi.
      let apiKey = auth.apiKey ?? (await ctx.modelRegistry.getApiKeyForProvider(provider));

      // Local providers may declare apiKey: "none" or "no-api-key-needed" —
      // the registry lookup can return undefined for those, so fall back to
      // the literal value.
      if (!apiKey) {
        const rawModel = ctx.modelRegistry.find(provider, modelId);
        const rawApiKey = (rawModel as unknown as { apiKey?: string })?.apiKey;
        if (rawApiKey === "none" || rawApiKey === "no-api-key-needed") {
          apiKey = rawApiKey;
        }
      }

      if (!apiKey) {
        const msg = "no API key";
        lastErrors.push(`[${provider}/${modelId}] ${msg}`);
        setAttemptLine(
          i + 1,
          attempts.length,
          provider,
          modelId,
          `Error seeking advice from advisor ${provider}/${modelId}!\n      -> ${shortMessage(msg)}`,
        );
        continue;
      }

      setAttemptLine(
        i + 1,
        attempts.length,
        provider,
        modelId,
        `Consulting advisor ${provider}/${modelId}...`,
      );
      const messages = [
        {
          role: "user" as const,
          content: [{ type: "text" as const, text: prompt }],
          timestamp: Date.now(),
        },
      ];

      // Scope the cache-affinity key per advisor provider/model so switching
      // advisors mid-session doesn't cause misses or cross-model collisions.
      const baseSessionId = getSessionIdForCache(ctx);
      const cacheSessionId = `${baseSessionId}:${provider}:${modelId}`;

      const options: Record<string, unknown> = {
        apiKey,
        headers: auth.headers,
        cacheRetention: cfg.cacheRetention,
        sessionId: cacheSessionId,
        signal,
      };

      // Apply reasoning effort only for OpenAI-compatible providers.
      // Use per-attempt override if set, else config default.
      const effectiveEffort = reasoningEffort || cfg.reasoningEffort;
      if (provider.toLowerCase().includes("openai") && effectiveEffort) {
        options.reasoningEffort = effectiveEffort;
      }

      try {
        const response = await complete(
          model,
          { messages },
          options as Parameters<typeof complete>[2],
        );
        const info = summarizeCompletion(response);

        if (info.text) {
          return {
            ok: true,
            text: info.text,
            provider,
            model: model.id,
            promptChars: prompt.length,
            transcriptChars: transcript.length,
            callIndex: callsThisSession,
            turnCallIndex: callsThisTurn,
            attemptLines,
          };
        }

        // Empty completion — treat as failure, try next.
        const detail = [
          info.errorMessage ? `error: ${info.errorMessage}` : null,
          info.stopReason ? `stopReason: ${info.stopReason}` : null,
          typeof info.outputTokens === "number"
            ? `outputTokens: ${info.outputTokens}`
            : null,
          typeof info.reasoningTokens === "number"
            ? `reasoningTokens: ${info.reasoningTokens}` : null,
        ]
          .filter(Boolean)
          .join(", ");

        const msg = `no text${detail ? ` (${detail})` : ""}`;
        lastErrors.push(`[${provider}/${modelId}] ${msg}`);
        setAttemptLine(
          i + 1,
          attempts.length,
          provider,
          modelId,
          `Error seeking advice from advisor ${provider}/${modelId}!\n      -> ${shortMessage(msg)}`,
        );

      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        const msg = shortMessage(message);
        lastErrors.push(`[${provider}/${modelId}] ${message}`);
        setAttemptLine(
          i + 1,
          attempts.length,
          provider,
          modelId,
          `Error seeking advice from advisor ${provider}/${modelId}!\n      -> ${msg}`,
        );
      }
    }

    // All attempts exhausted.
    return {
      ok: false,
      text: `All advisor models failed:\n${lastErrors.map((e) => `  - ${e}`).join("\n")}.\nContinue without advisor and verify locally.`,
      provider: lastAttempt?.provider ?? "",
      model: lastAttempt?.model ?? "",
      promptChars: prompt.length,
      transcriptChars: transcript.length,
      callIndex: callsThisSession,
      turnCallIndex: callsThisTurn,
      error: lastErrors.join("; "),
      attemptLines,
    };
  }

  function formatAttemptLines(lines: string[]): string {
    return lines.filter(Boolean).join("\n\n");
  }

  function formatAdvisorResult(result: AdvisorRunResult): string {
    const history = result.ok
      ? (result.attemptLines ?? []).slice(0, -1)
      : (result.attemptLines ?? []);
    const formattedHistory = formatAttemptLines(history);
    const prefix = formattedHistory ? `${formattedHistory}\n\n` : "";
    const status = result.ok ? "Advice" : "Advisor unavailable";
    return `${prefix}${status} from ${result.provider}/${result.model}:\n\n${result.text}`;
  }

  pi.on("session_start", async (_event, ctx) => {
    restoreAdvisorCount(ctx);

    if (ctx.hasUI) {
      const cfg = getConfig();
      const attempts = resolveAdvisorChain(cfg);
      const chainLabel = attempts.length > 1
        ? attempts.map((a) => `${a.provider}/${a.model}`).join(" → ")
        : `${attempts[0].provider}/${attempts[0].model}`;
      ctx.ui.notify(
        `Advisor extension loaded: ${chainLabel}`,
        "info",
      );
    }
  });

  pi.on("agent_start", async () => {
    callsThisTurn = 0;
  });

  pi.on("before_agent_start", async (event) => ({
    systemPrompt: `${event.systemPrompt}\n\n${ADVISOR_GUIDANCE_TEXT}`,
  }));

  pi.registerTool({
    name: TOOL_NAME,
    label: "Advisor",
    description:
      "Ask a stronger advisor model for strategic guidance. The advisor sees the current Pi conversation transcript and returns a compact plan, critique, or final review. It does not edit files or run tools.",
    promptSnippet:
      "Ask a stronger advisor model for complex planning, stuck states, approach changes, or final review.",
    promptGuidelines: [
      "Use advisor after orientation reads on complex coding tasks, before committing to a non-trivial implementation approach.",
      "Use advisor when stuck after repeated command/test failures, contradictory evidence, or non-converging edits.",
      "Use advisor before declaring a complex task complete, especially when verification is incomplete or risky.",
      "Do not use advisor for simple one-step tasks or as a substitute for reading files and running tests.",
    ],
    parameters: Type.Object({
      stage: Type.Optional(
        StringEnum(
          ["orientation", "approach", "stuck", "final_review"] as const,
          {
            description: "Why advisor is being called right now.",
          },
        ),
      ),
      question: Type.Optional(
        Type.String({
          description:
            "Specific question or decision for the advisor. Include your hypothesis, errors, or proposed plan.",
        }),
      ),
      max_words: Type.Optional(
        Type.Number({
          description:
            "Approximate maximum advice length. Default PI_ADVISOR_MAX_WORDS, capped at 1200.",
        }),
      ),
      context: Type.Optional(
        Type.String({
          description:
            "Optional executor-curated context (relevant code, diffs, errors, prior reasoning). When provided, the advisor treats it as primary signal over the conversation transcript. Useful for focused reviews or to reduce token cost on long sessions.",
        }),
      ),
      include_transcript: Type.Optional(
        Type.Boolean({
          description:
            "Whether to also send the full conversation transcript. Defaults to true. Set to false to send only `context` (must be non-empty) for self-contained questions, privacy-sensitive flows, or to avoid noise from long sessions. Combining true with a non-empty `context` is allowed but doubles tokens; prefer false when you already know what matters.",
        }),
      ),
    }),
    prepareArguments(args) {
      if (!args || typeof args !== "object") return {};
      return args;
    },
    async execute(_toolCallId, params: AdvisorParams, signal, onUpdate, ctx) {
      const cfg = getConfig();

      let lastProgressMsg = "";
      const result = await runAdvisor(ctx, params, signal, (attemptLines, _index, _total, provider, model) => {
        const progressMsg = formatAttemptLines(attemptLines);
        if (!progressMsg || progressMsg === lastProgressMsg) return;
        lastProgressMsg = progressMsg;

        onUpdate?.({
          content: [
            {
              type: "text",
              text: progressMsg,
            },
          ],
          details: {
            advisor: {
              status: "running",
              provider,
              model,
            },
          },
        });
      });
      return {
        content: [{ type: "text", text: formatAdvisorResult(result) }],
        details: {
          advisor: {
            ok: result.ok,
            provider: result.provider,
            model: result.model,
            callIndex: result.callIndex,
            turnCallIndex: result.turnCallIndex,
            maxPerTurn: cfg.maxPerTurn,
            promptChars: result.promptChars,
            transcriptChars: result.transcriptChars,
            error: result.error,
          },
        },
      };
    },
  });

  pi.registerCommand("advise", {
    description:
      "Manually ask the configured advisor model and inject the advice as steering context",
    handler: async (args, ctx) => {
      await ctx.waitForIdle();

      if (ctx.hasUI) {
        ctx.ui.notify("Consulting advisor...", "info");
      }

      const result = await runAdvisor(ctx, {
        stage: "manual",
        question:
          args.trim() ||
          "Review the current work and advise the executor on the best next step.",
      });

      // Don't steer the executor with cap/privacy/auth error messages — those
      // are meta problems for the human, not guidance for the coding agent.
      if (!result.ok) {
        if (ctx.hasUI) {
          ctx.ui.notify(
            `Advisor unavailable (${result.error ?? "unknown"}): ${result.text}`,
            "warning",
          );
        }
        return;
      }

      const content = formatAdvisorResult(result);

      pi.sendMessage(
        {
          customType: ADVISOR_CUSTOM_MESSAGE_TYPE,
          content,
          display: true,
          details: {
            advisor: {
              ok: result.ok,
              provider: result.provider,
              model: result.model,
              callIndex: result.callIndex,
              turnCallIndex: result.turnCallIndex,
              promptChars: result.promptChars,
              transcriptChars: result.transcriptChars,
              error: result.error,
            },
          },
        },
        {
          triggerTurn: true,
          deliverAs: "steer",
        },
      );
    },
  });

  pi.registerCommand("advisor-status", {
    description: "Show advisor extension status",
    handler: async (_args, ctx) => {
      const cfg = getConfig();
      const attempts = resolveAdvisorChain(cfg);
      const chainLines = attempts.map((a, idx) => {
        const eff = a.reasoningEffort ? `:${a.reasoningEffort}` : "";
        return `${idx + 1}. ${a.provider}/${a.model}${eff}`;
      }).join("\n");
      ctx.ui.notify(
        [
          `advisor chain (${attempts.length}):`,
          chainLines,
          `allowed: ${cfg.allowed ? "yes" : "no"}`,
          `redaction: ${cfg.redact ? "on" : "off"}`,
          `cache retention: ${cfg.cacheRetention}`,
          `calls this turn / total this session: ${callsThisTurn}/${callsThisSession}`,
          `cap per-turn: ${cfg.maxPerTurn} (no session cap)`,
          `reasoning effort (openai): ${cfg.reasoningEffort || "(default)"}`,
          `default max_words: ${cfg.defaultMaxWords}`,
          `config is read lazily; edit env then /reload to apply.`,
        ].join("\n"),
        "info",
      );
    },
  });
}
