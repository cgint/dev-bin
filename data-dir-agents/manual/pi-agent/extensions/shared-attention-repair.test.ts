import { expect, test } from "bun:test";
import fixture from "./fixtures/user-correction-over-implementation.json";
import sharedAttentionRepair from "./shared-attention-repair";
import {
  buildProjectionPrompt,
  serializeRepairContext,
  resolveApiKey,
  selectionStatus,
  selectEpisode,
  serializeEpisode,
  type RepairEntry,
} from "./shared-attention-repair";

const message = (id: string, role: string, content: unknown): RepairEntry => ({
  id,
  timestamp: `2026-08-27T00:00:${id}.000Z`,
  type: "message",
  message: { role, content },
});

const projection = `## Current direction
- User: The user asked to inspect the bounded conversation. [#u1]

## Agent's reading
- Assistant: The card is candidate-only. [#a1]

## Mismatch or correction
- None in inspected span.

## Established together
- None in inspected span.

## Still open
- None in inspected span.`;

test("selection crosses compaction boundaries, excludes repair cards, and reports non-conversation omissions", () => {
  const entries: RepairEntry[] = [
    message("u0", "user", "old"),
    { id: "c1", timestamp: "2026-08-27T00:00:c1.000Z", type: "compaction" },
    message("u1", "user", "inspect"),
    { id: "r1", timestamp: "2026-08-27T00:00:r1.000Z", type: "custom_message", customType: "shared-attention-repair", content: "prior card" },
    { id: "m1", timestamp: "2026-08-27T00:00:m1.000Z", type: "model_change" },
    message("a1", "assistant", "answer"),
  ];
  const selected = selectEpisode(entries, 30);
  expect(selected.entries.map((item) => item.id)).toEqual(["u0", "u1", "a1"]);
  expect(selected.availableUserTurns).toBe(2);
  expect(selected.omittedEarlierUserTurns).toBe(false);
  expect(selectionStatus(selected)).toBe("Repairing the current session (2 user turns)...");
  expect(selected.compactionRelation).toBe("selected range crosses latest compaction c1");
  expect(selected.omittedPriorRepairs).toBe(1);
  expect(selected.omittedNonConversation).toBe(2);
});

test("selection retains every message in the requested complete user-turn span", () => {
  const selected = selectEpisode([
    message("u1", "user", "old"),
    message("u2", "user", "inspect"),
    message("a1", "assistant", "calling tool"),
    message("t1", "toolResult", "tool output"),
    message("a2", "assistant", "answer"),
  ], 1);
  expect(selected.entries.map((item) => item.id)).toEqual(["u2", "a1", "t1", "a2"]);
  expect(selected.availableUserTurns).toBe(2);
  expect(selected.omittedEarlierUserTurns).toBe(true);
});

test("selection caps the default-sized window by user turns rather than message events", () => {
  const entries = Array.from({ length: 101 }, (_, index) => message(`u${index + 1}`, "user", `topic ${index + 1}`));
  const selected = selectEpisode(entries, 100);
  expect(selected.entries).toHaveLength(100);
  expect(selected.entries[0].id).toBe("u2");
  expect(selected.availableUserTurns).toBe(101);
  expect(selected.omittedEarlierUserTurns).toBe(true);
  expect(selectionStatus(selected)).toBe("Repairing the last 100 user turns...");
});

test("serialization includes visible text and tool data but excludes thinking and images", () => {
  const text = serializeEpisode([
    message("u1", "user", [{ type: "text", text: "visible user" }, { type: "image", data: "BINARY" }]),
    message("a1", "assistant", [
      { type: "thinking", thinking: "hidden reasoning" },
      { type: "text", text: "visible assistant" },
      { type: "toolCall", name: "read", arguments: { path: "x.ts" } },
    ]),
    message("t1", "toolResult", [{ type: "toolResult", content: [{ type: "text", text: "nested tool text" }, { type: "image", data: "NOPE" }] }]),
  ]);
  expect(text).toContain("visible user");
  expect(text).toContain("visible assistant");
  expect(text).toContain("Tool call: read (arguments omitted; inspect [#a1] if needed)");
  expect(text).toContain("Tool result: 16 visible characters omitted; inspect [#t1] if needed");
  expect(text).not.toContain("nested tool text");
  expect(text).not.toContain("hidden reasoning");
  expect(text).not.toContain("BINARY");
  expect(text).not.toContain("NOPE");
});

test("repair context separates user direction from agent interpretation", () => {
  const context = serializeRepairContext(fixture.entries as RepairEntry[]);
  const agentStart = context.indexOf("\n\nAGENT'S READING\n");
  const observedStart = context.indexOf("\n\nOBSERVED WORK\n");
  const userDirection = context.slice(0, agentStart);
  const agentReading = context.slice(agentStart, observedStart);
  const observedWork = context.slice(observedStart + 2);
  expect(userDirection).toContain("USER'S CURRENT DIRECTION");
  expect(userDirection).toContain("[#u1]");
  expect(userDirection).toContain("[#u2]");
  expect(userDirection).not.toContain("[#a1]");
  expect(agentReading).toContain("AGENT'S READING");
  expect(agentReading).toContain("[#a1]");
  expect(agentReading).not.toContain("[#u1]");
  expect(observedWork).toBe("OBSERVED WORK\n- None in inspected span.");
});

test("prompt centers the user's active correction over assistant implementation reporting", () => {
  const selected = selectEpisode(fixture.entries as RepairEntry[], 30);
  const prompt = buildProjectionPrompt(serializeRepairContext(selected.entries), 300);
  expect(selected.entries.map((entry) => entry.id)).toEqual(["u1", "a1", "u2"]);
  expect(prompt).toContain("The user's active request, correction, objection, or constraint is the primary anchor.");
  expect(prompt).toContain("Never infer a human goal, requirement, decision, or correction from AGENT'S READING or OBSERVED WORK.");
  expect(prompt).toContain("AGENT'S READING may show what the assistant says it understood, assumed, or reported.");
  expect(prompt).toContain("Agent's reading states the relevant visible assistant understanding or assumption");
  expect(prompt).toContain("Established together contains only explicit shared decisions or results the user explicitly accepted");
  expect(prompt).toContain("Do not include failed commands, write boundaries, deployment, tests, or other execution mechanics");
  expect(prompt).toContain("Stop making the implementation itself the subject.");
  expect(prompt).toContain("Do not add scope counts, timestamps, provider details, or other inspection metadata.");
  const truncatedPrompt = buildProjectionPrompt(serializeRepairContext(selected.entries), 300, true);
  expect(truncatedPrompt).toContain("Under ## Still open, add exactly: - Earlier conversation was not inspected.");
});

test("auth resolver accepts model literals and provider fallback", () => {
  expect(resolveApiKey(undefined, "provider-key", "none")).toBe("none");
  expect(resolveApiKey(undefined, "provider-key", "no-api-key-needed")).toBe("no-api-key-needed");
  expect(resolveApiKey(undefined, "provider-key", undefined)).toBe("provider-key");
});

function commandHarness(
  confirm: boolean,
  output = projection,
  usage: { input: number; output: number; cacheRead: number; cacheWrite: number } | null = {
    input: 1200,
    output: 42,
    cacheRead: 0,
    cacheWrite: 0,
  },
) {
  let command: ((args: string, ctx: any) => Promise<void>) | undefined;
  const calls = {
    auth: 0,
    complete: 0,
    sent: [] as Array<{ value: unknown; options: unknown }>,
    notes: [] as unknown[],
    find: [] as Array<{ provider: string; model: string }>,
    confirm: [] as string[],
  };
  sharedAttentionRepair({
    registerCommand: (_name: string, spec: { handler: (args: string, ctx: any) => Promise<void> }) => {
      command = spec.handler;
    },
    sendMessage: (value: unknown, options: unknown) => calls.sent.push({ value, options }),
  } as any);
  const ctx = {
    mode: "tui",
    waitForIdle: async () => {},
    sessionManager: {
      getBranch: () => [message("u1", "user", "inspect"), message("a1", "assistant", "answer")],
      getSessionId: () => "session",
      getLeafId: () => "leaf",
    },
    ui: {
      confirm: async (_prompt: string, grant: string) => {
        calls.confirm.push(grant);
        return confirm;
      },
      notify: (...note: unknown[]) => calls.notes.push(note),
    },
    modelRegistry: {
      find: (provider: string, model: string) => {
        calls.find.push({ provider, model });
        return { apiKey: "no-api-key-needed" };
      },
      getApiKeyAndHeaders: async () => {
        calls.auth++;
        return { ok: false, error: "not needed" };
      },
      getApiKeyForProvider: async () => "provider-key",
      complete: async () => {
        calls.complete++;
        return { content: [{ type: "text", text: output }], usage };
      },
    },
  };
  return { calls, command: (args = "") => command!(args, ctx) };
}

test("command invokes the bounded model call without a repair-specific confirmation", async () => {
  process.env.PI_ATTENTION_REPAIR_PROVIDER = "p";
  process.env.PI_ATTENTION_REPAIR_MODEL = "m";
  const harness = commandHarness(false);
  await harness.command();
  expect(harness.calls.confirm).toEqual([]);
  expect(harness.calls.complete).toBe(1);
  expect(harness.calls.sent).toHaveLength(1);
});

test("command falls back to owned defaults when repair env vars are unset", async () => {
  const prevProvider = process.env.PI_ATTENTION_REPAIR_PROVIDER;
  const prevModel = process.env.PI_ATTENTION_REPAIR_MODEL;
  delete process.env.PI_ATTENTION_REPAIR_PROVIDER;
  delete process.env.PI_ATTENTION_REPAIR_MODEL;
  try {
    const harness = commandHarness(true);
    await harness.command();
    expect(harness.calls.find).toEqual([
      { provider: "google", model: "gemini-3.7-flash" },
    ]);
    expect(harness.calls.complete).toBe(1);
    expect(harness.calls.sent).toHaveLength(1);
    expect(harness.calls.sent[0]).toMatchObject({
      options: { triggerTurn: false },
      value: expect.objectContaining({
        details: expect.objectContaining({
          provider: "google",
          model: "gemini-3.7-flash",
          usage: { input: 1200, output: 42, cacheRead: 0, cacheWrite: 0 },
        }),
        content: projection,
      }),
    });
    expect(harness.calls.confirm).toEqual([]);
  } finally {
    if (prevProvider === undefined) {
      delete process.env.PI_ATTENTION_REPAIR_PROVIDER;
    } else {
      process.env.PI_ATTENTION_REPAIR_PROVIDER = prevProvider;
    }
    if (prevModel === undefined) {
      delete process.env.PI_ATTENTION_REPAIR_MODEL;
    } else {
      process.env.PI_ATTENTION_REPAIR_MODEL = prevModel;
    }
  }
});

test("command publishes the candidate without triggering or an evidence appendix", async () => {
  process.env.PI_ATTENTION_REPAIR_PROVIDER = "p";
  process.env.PI_ATTENTION_REPAIR_MODEL = "m";
  const harness = commandHarness(true);
  await harness.command();
  expect(harness.calls.complete).toBe(1);
  expect(harness.calls.notes).toEqual([
    ["Preparing shared attention repair...", "info"],
    ["Repairing the current session (1 user turn)...", "info"],
    ["Shared attention repaired · 1,200 input · 42 output tokens", "info"],
  ]);
  expect(harness.calls.sent).toEqual([expect.objectContaining({
    options: { triggerTurn: false },
    value: expect.objectContaining({ content: projection }),
  })]);
  expect((harness.calls.sent[0].value as { content: string }).content).not.toContain("## Evidence and edges");
});

test("command publishes an imperfect candidate instead of discarding the outcome", async () => {
  process.env.PI_ATTENTION_REPAIR_PROVIDER = "p";
  process.env.PI_ATTENTION_REPAIR_MODEL = "m";
  const imperfect = "The user asked about shared attention, but this response misses the requested card format.";
  const candidate = commandHarness(true, imperfect);
  await candidate.command();
  expect(candidate.calls.complete).toBe(1);
  expect(candidate.calls.sent).toEqual([expect.objectContaining({
    value: expect.objectContaining({ content: imperfect }),
    options: { triggerTurn: false },
  })]);
  expect(candidate.calls.notes.some((note) => String(note).includes("rejected"))).toBe(false);

  const withoutUsage = commandHarness(true, imperfect, null);
  await withoutUsage.command();
  expect(withoutUsage.calls.notes.at(-1)).toEqual(["Shared attention repaired · token usage unavailable.", "info"]);

  const nonInteger = commandHarness(true);
  await nonInteger.command("20junk");
  expect(nonInteger.calls.auth).toBe(0);
  expect(nonInteger.calls.complete).toBe(0);
  expect(nonInteger.calls.sent).toHaveLength(0);
});
