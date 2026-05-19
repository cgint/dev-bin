/**
 * Diesel-KM Extension — LLM energy × diesel-car distance (model-aware)
 *
 * Uses Pi session usage metadata plus a minimal TypeScript port of EcoLogits'
 * LLM request-energy math, backed by EcoLogits models.json when available.
 *
 * Place this file at:
 *   ~/.pi/agent/extensions/diesel-km.ts
 */

import { existsSync, readFileSync } from "fs";
import { homedir } from "os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// ── EcoLogits constants from ecologits/impacts/llm.py ───────────────────────
const MODEL_QUANTIZATION_BITS = 16;
const GPU_ENERGY_ALPHA = 1.1665273170451914e-06;
const GPU_ENERGY_BETA = -0.011205921025579175;
const GPU_ENERGY_GAMMA = 4.052928146734005e-05;
const LATENCY_ALPHA = 0.0006785088094353663;
const LATENCY_BETA = 0.0003119310311688259;
const LATENCY_GAMMA = 0.019473717579473387;
const GPU_MEMORY_GB = 80;
const SERVER_GPUS = 8;
const SERVER_POWER_KW = 1.2;
const BATCH_SIZE = 64;

// EcoLogits-derived provider PUE values.
// Provenance: mirrored from EcoLogits `ecologits/tracers/utils.py` PROVIDER_CONFIG_MAP
// as inspected on 2026-05-19. These are not local extension assumptions; keep in
// sync with EcoLogits if that upstream config changes.
const PROVIDER_PUE: Record<string, Range> = {
  anthropic: { min: 1.09, max: 1.14 },
  cohere: { min: 1.09, max: 1.09 },
  google: { min: 1.09, max: 1.09 },
  huggingface: { min: 1.09, max: 1.14 },
  mistral: { min: 1.16, max: 1.16 },
  openai: { min: 1.20, max: 1.20 },
  azure: { min: 1.20, max: 1.20 },
};
const DEFAULT_PUE: Range = { min: 1.20, max: 1.20 };

// Previous MVP fallback: 2024 EcoLogits baseline, 1200 output tokens → 0.004729 kWh.
const FALLBACK_KWH_PER_OUTPUT_TOKEN = 0.004729 / 1200;

// ── Diesel-car constants ─────────────────────────────────────────────────────
const DIESEL_KWH_PER_LITER = 9.8;
const DIESEL_L_PER_100KM = 5.0;
const DIESEL_KWH_PER_KM = DIESEL_KWH_PER_LITER * DIESEL_L_PER_100KM / 100; // 0.49

// ── EcoLogits model data ─────────────────────────────────────────────────────
function expandHome(path: string): string {
  return path === "~" || path.startsWith("~/")
    ? path.replace(/^~(?=$|\/)/, homedir())
    : path;
}

const ECOLOGITS_MODELS_JSON = expandHome(
  process.env.ECOLOGITS_MODELS_JSON ||
  "~/dev-external/ecologits/ecologits/data/models.json",
);

type Range = { min: number; max: number };
type SessionEntry = {
  type: string;
  message?: {
    role?: string;
    usage?: { input?: number; output?: number; totalTokens?: number };
    api?: { model?: string; provider?: string };
    model?: string;
    provider?: string;
  };
  model_change?: { model?: string; provider?: string; id?: string; name?: string };
  provider?: string;
  model?: string;
};

type ModelInfo = {
  provider: string;
  name: string;
  canonicalKey: string;
  activeParamsB: Range;
  totalParamsB: Range;
  tps?: number;
  ttft?: number;
};

type EnergyEstimate = {
  energyKwh: Range;
  meters: Range;
  factorKwhPerToken: Range;
  source: string;
  activeParamsB?: Range;
  totalParamsB?: Range;
  pue?: Range;
};

type ModelStats = {
  key: string;
  label: string;
  outputTokens: number;
  energyKwh: Range;
  meters: Range;
  factorKwhPerToken: Range;
  source: string;
  activeParamsB?: Range;
  totalParamsB?: Range;
};

type DieselStats = {
  totalOutputTokens: number;
  totalInputTokens: number;
  totalTokens: number;
  totalEnergyKwh: Range;
  totalMeters: Range;
  modelBreakdown: ModelStats[];
  display: string;
  modelDataLoaded: boolean;
};

const MODEL_INDEX = loadModelIndex();

function loadModelIndex(): {
  loaded: boolean;
  models: Map<string, ModelInfo>;
  aliases: Map<string, string>;
  error?: string;
} {
  const models = new Map<string, ModelInfo>();
  const aliases = new Map<string, string>();

  try {
    if (!existsSync(ECOLOGITS_MODELS_JSON)) {
      return { loaded: false, models, aliases, error: `not found: ${ECOLOGITS_MODELS_JSON}` };
    }

    const raw = JSON.parse(readFileSync(ECOLOGITS_MODELS_JSON, "utf8"));

    for (const rec of raw.models || []) {
      const provider = normalizeProvider(rec.provider);
      const name = normalizeModel(rec.name);
      const params = parseArchitectureParameters(rec.architecture);
      if (!provider || !name || !params) continue;

      const info: ModelInfo = {
        provider,
        name,
        canonicalKey: modelKey(provider, name),
        activeParamsB: params.active,
        totalParamsB: params.total,
        tps: finiteNumber(rec.deployment?.tps),
        ttft: finiteNumber(rec.deployment?.ttft),
      };
      models.set(info.canonicalKey, info);
      // Also allow provider-less fallback by model name when unique enough for Pi display.
      if (!models.has(modelKey("", name))) models.set(modelKey("", name), info);
    }

    for (const alias of raw.aliases || []) {
      const provider = normalizeProvider(alias.provider);
      const name = normalizeModel(alias.name);
      const target = normalizeModel(alias.alias);
      if (provider && name && target) {
        aliases.set(modelKey(provider, name), modelKey(provider, target));
        aliases.set(modelKey("", name), modelKey(provider, target));
      }
    }

    return { loaded: true, models, aliases };
  } catch (err) {
    return { loaded: false, models, aliases, error: String(err) };
  }
}

function parseArchitectureParameters(architecture: any): { active: Range; total: Range } | undefined {
  const parameters = architecture?.parameters;
  if (parameters == null) return undefined;

  if (architecture?.type === "moe" && parameters.total != null && parameters.active != null) {
    return { total: toRange(parameters.total), active: toRange(parameters.active) };
  }

  const total = toRange(parameters);
  return { total, active: total };
}

function toRange(value: any): Range {
  if (typeof value === "number") return { min: value, max: value };
  if (typeof value?.min === "number" && typeof value?.max === "number") {
    return { min: value.min, max: value.max };
  }
  if (typeof value?.total === "number") return { min: value.total, max: value.total };
  return { min: 0, max: 0 };
}

function finiteNumber(value: any): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function normalizeProvider(provider: unknown): string {
  return String(provider || "").trim().toLowerCase().replace(/^openai-codex$/, "openai");
}

function normalizeModel(model: unknown): string {
  return String(model || "").trim().toLowerCase();
}

function modelKey(provider: string, model: string): string {
  return provider ? `${provider}/${model}` : model;
}

function resolveModel(provider: string | undefined, model: string | undefined): ModelInfo | undefined {
  const normalizedProvider = normalizeProvider(provider);
  const normalizedModel = normalizeModel(model);
  if (!normalizedModel) return undefined;

  const candidates = [
    modelKey(normalizedProvider, normalizedModel),
    modelKey("", normalizedModel),
    ...stripModelDecorations(normalizedModel).map((m) => modelKey(normalizedProvider, m)),
    ...stripModelDecorations(normalizedModel).map((m) => modelKey("", m)),
  ];

  for (const candidate of candidates) {
    const aliasTarget = MODEL_INDEX.aliases.get(candidate);
    const resolvedKey = aliasTarget || candidate;
    const info = MODEL_INDEX.models.get(resolvedKey);
    if (info) return info;
  }

  return undefined;
}

function stripModelDecorations(model: string): string[] {
  const variants = new Set<string>();
  variants.add(model);
  variants.add(model.replace(/^\([^)]*\)\s*/, ""));
  variants.add(model.replace(/\s*[•].*$/, ""));
  variants.add(model.replace(/\s+\b(low|medium|high|auto)\b.*$/, ""));
  return [...variants].map((s) => s.trim()).filter(Boolean);
}

// ── EcoLogits request-energy port ────────────────────────────────────────────

function estimateEnergy(outputTokens: number, provider?: string, model?: string): EnergyEstimate {
  const info = resolveModel(provider, model);
  if (!info) {
    const energy = scalarRange(outputTokens * FALLBACK_KWH_PER_OUTPUT_TOKEN);
    return {
      energyKwh: energy,
      meters: energyToMeters(energy),
      factorKwhPerToken: scalarRange(FALLBACK_KWH_PER_OUTPUT_TOKEN),
      source: `fallback 2024 baseline (model not found: ${provider || "?"}/${model || "?"})`,
    };
  }

  const pue = PROVIDER_PUE[info.provider] || DEFAULT_PUE;
  const minEnergy = computeEcoLogitsRequestEnergy({
    activeParamsB: info.activeParamsB.min,
    totalParamsB: info.totalParamsB.min,
    outputTokens,
    pue: pue.min,
    tps: info.tps,
    ttft: info.ttft,
  });
  const maxEnergy = computeEcoLogitsRequestEnergy({
    activeParamsB: info.activeParamsB.max,
    totalParamsB: info.totalParamsB.max,
    outputTokens,
    pue: pue.max,
    tps: info.tps,
    ttft: info.ttft,
  });
  const energy = normalizeRange({ min: minEnergy, max: maxEnergy });

  return {
    energyKwh: energy,
    meters: energyToMeters(energy),
    factorKwhPerToken: divideRange(energy, outputTokens || 1),
    source: `EcoLogits models.json (${info.provider}/${info.name})`,
    activeParamsB: info.activeParamsB,
    totalParamsB: info.totalParamsB,
    pue,
  };
}

function computeEcoLogitsRequestEnergy(args: {
  activeParamsB: number;
  totalParamsB: number;
  outputTokens: number;
  pue: number;
  tps?: number;
  ttft?: number;
}): number {
  // gpu_energy(): energy consumption of a single GPU in kWh.
  const gpuEnergyPerTokenKwh =
    (GPU_ENERGY_ALPHA * Math.exp(GPU_ENERGY_BETA * BATCH_SIZE) * args.activeParamsB + GPU_ENERGY_GAMMA) / 1000;
  const gpuEnergyKwh = args.outputTokens * gpuEnergyPerTokenKwh;

  // model_required_memory() + gpu_required_count().
  const modelRequiredMemoryGb = 1.2 * args.totalParamsB * MODEL_QUANTIZATION_BITS / 8;
  const gpuRequiredCount = roundUpPowerOfTwo(Math.ceil(modelRequiredMemoryGb / GPU_MEMORY_GB));

  // generation_latency(). EcoLogits caps to measured request_latency; Pi does not expose it here.
  const latencyPerToken = args.tps ? 1 / args.tps :
    LATENCY_ALPHA * args.activeParamsB + LATENCY_BETA * BATCH_SIZE + LATENCY_GAMMA;
  const generationLatencyS = args.outputTokens * latencyPerToken + (args.ttft || 0);

  // server_energy(), then request_energy().
  const serverEnergyKwh =
    (generationLatencyS / 3600) * SERVER_POWER_KW * (gpuRequiredCount / SERVER_GPUS) * (1 / BATCH_SIZE);

  return args.pue * (serverEnergyKwh + gpuRequiredCount * gpuEnergyKwh);
}

function roundUpPowerOfTwo(n: number): number {
  if (!Number.isFinite(n) || n <= 1) return 1;
  return 2 ** Math.ceil(Math.log2(n));
}

function scalarRange(value: number): Range {
  return { min: value, max: value };
}

function normalizeRange(range: Range): Range {
  return range.min <= range.max ? range : { min: range.max, max: range.min };
}

function addRange(a: Range, b: Range): Range {
  return { min: a.min + b.min, max: a.max + b.max };
}

function divideRange(a: Range, divisor: number): Range {
  return { min: a.min / divisor, max: a.max / divisor };
}

function energyToMeters(kwh: Range): Range {
  return { min: (kwh.min / DIESEL_KWH_PER_KM) * 1000, max: (kwh.max / DIESEL_KWH_PER_KM) * 1000 };
}

function mean(range: Range): number {
  return (range.min + range.max) / 2;
}

function sameRange(range: Range, relTolerance = 0.01): boolean {
  const m = Math.max(Math.abs(mean(range)), 1e-12);
  return Math.abs(range.max - range.min) / m <= relTolerance;
}

// ── Session/model extraction ─────────────────────────────────────────────────

function extractModelRef(entry: SessionEntry): { provider?: string; model?: string } | undefined {
  if (entry.type === "message" && entry.message) {
    const msg = entry.message;
    const model = msg.model || msg.api?.model;
    const provider = msg.provider || msg.api?.provider;
    if (model || provider) return { provider, model };
  }

  if (entry.type === "model_change") {
    const anyEntry = entry as any;
    const change = entry.model_change || anyEntry.model || anyEntry.data || anyEntry;
    const model = change?.model || change?.id || change?.name;
    const provider = change?.provider;
    if (model || provider) return { provider, model };
  }

  if (entry.model || entry.provider) return { provider: entry.provider, model: entry.model };
  return undefined;
}

function contextModelRef(ctx: any): { provider?: string; model?: string } | undefined {
  const modelObj = ctx?.model;
  if (modelObj) {
    const provider = modelObj.provider;
    const model = modelObj.id || modelObj.name || modelObj.model;
    if (model || provider) return { provider, model };
  }

  const session = ctx?.sessionManager?.getSession?.();
  if (session?.model || session?.provider) return { provider: session.provider, model: session.model };
  return undefined;
}

function modelLabel(ref: { provider?: string; model?: string }, estimate: EnergyEstimate): string {
  const provider = normalizeProvider(ref.provider) || "?";
  const model = normalizeModel(ref.model) || "unknown";
  const params = estimate.activeParamsB
    ? `active ${formatRange(estimate.activeParamsB, "B")}`
    : "fallback";
  return `${provider}/${model} (${params})`;
}

// ── Stats ────────────────────────────────────────────────────────────────────

function computeStats(branch: SessionEntry[], fallback?: { provider?: string; model?: string }): DieselStats {
  let totalInputTokens = 0;
  let totalOutputTokens = 0;
  let totalTokens = 0;
  let lastModel = fallback;
  let totalEnergyKwh = scalarRange(0);

  const byModel = new Map<string, ModelStats>();

  for (const entry of branch) {
    const ref = extractModelRef(entry);
    if (ref?.model || ref?.provider) lastModel = { ...lastModel, ...ref };

    if (entry.type !== "message" || entry.message?.role !== "assistant") continue;
    const usage = entry.message.usage;
    if (!usage) continue;

    const input = usage.input || 0;
    const output = usage.output || 0;
    const tokens = usage.totalTokens || input + output;
    totalInputTokens += input;
    totalOutputTokens += output;
    totalTokens += tokens;
    if (output <= 0) continue;

    const messageRef = extractModelRef(entry) || lastModel || fallback || {};
    const estimate = estimateEnergy(output, messageRef.provider, messageRef.model);
    totalEnergyKwh = addRange(totalEnergyKwh, estimate.energyKwh);

    const key = `${normalizeProvider(messageRef.provider)}/${normalizeModel(messageRef.model)}|${estimate.source}`;
    const current = byModel.get(key);
    if (current) {
      current.outputTokens += output;
      current.energyKwh = addRange(current.energyKwh, estimate.energyKwh);
      current.meters = energyToMeters(current.energyKwh);
      current.factorKwhPerToken = divideRange(current.energyKwh, current.outputTokens || 1);
    } else {
      byModel.set(key, {
        key,
        label: modelLabel(messageRef, estimate),
        outputTokens: output,
        energyKwh: estimate.energyKwh,
        meters: estimate.meters,
        factorKwhPerToken: estimate.factorKwhPerToken,
        source: estimate.source,
        activeParamsB: estimate.activeParamsB,
        totalParamsB: estimate.totalParamsB,
      });
    }
  }

  const totalMeters = energyToMeters(totalEnergyKwh);
  const modelBreakdown = [...byModel.values()].sort((a, b) => mean(b.energyKwh) - mean(a.energyKwh));

  return {
    totalInputTokens,
    totalOutputTokens,
    totalTokens,
    totalEnergyKwh,
    totalMeters,
    modelBreakdown,
    display: formatDistance(totalMeters),
    modelDataLoaded: MODEL_INDEX.loaded,
  };
}

// ── Formatting ───────────────────────────────────────────────────────────────

function formatDistance(meters: Range): string {
  return formatRangeValue(meters, (m) => {
    if (m < 0.01) return `${(m * 1000).toFixed(1)} mm`;
    if (m < 1) return `${(m * 100).toFixed(0)} cm`;
    if (m < 100) return `${m.toFixed(1)} m`;
    const km = m / 1000;
    if (km < 10) return `${km.toFixed(3)} km`;
    return `${km.toFixed(2)} km`;
  });
}

function fmtToken(n: number): string {
  if (n < 1000) return String(n);
  if (n < 100_000) return `${(n / 1000).toFixed(1)}k`;
  return `${(n / 1_000_000).toFixed(1)}M`;
}

function fmtEnergy(kwh: Range): string {
  return formatRangeValue(kwh, (v) => {
    if (v < 0.001) return `${(v * 1e6).toFixed(1)} µWh`;
    if (v < 1) return `${(v * 1000).toFixed(2)} mWh`;
    return `${v.toFixed(3)} kWh`;
  });
}

function formatRange(range: Range, unit = ""): string {
  const fmt = (value: number) => Number.isInteger(value) ? String(value) : value.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
  return sameRange(range) ? `${fmt(mean(range))}${unit}` : `${fmt(range.min)}–${fmt(range.max)}${unit}`;
}

function formatRangeValue(range: Range, formatter: (value: number) => string): string {
  if (sameRange(range)) return formatter(mean(range));
  return `${formatter(range.min)}–${formatter(range.max)}`;
}

function fmtFactor(range: Range): string {
  return formatRangeValue(range, (v) => `${v.toExponential(3)} kWh/output-token`);
}

function currentModelFromBranch(branch: SessionEntry[]): { provider?: string; model?: string } | undefined {
  let current: { provider?: string; model?: string } | undefined;
  for (const entry of branch) {
    const ref = extractModelRef(entry);
    if (ref?.provider || ref?.model) current = { ...current, ...ref };
  }
  return current;
}

function footerEntries(ctx: any): SessionEntry[] {
  return (ctx.sessionManager.getEntries?.() || ctx.sessionManager.getBranch?.() || []) as SessionEntry[];
}

function updateDieselStatus(
  ctx: any,
  getFallbackModel: () => { provider?: string; model?: string } | undefined,
): void {
  if (!ctx.hasUI) return;

  const entries = footerEntries(ctx);
  const fallback = currentModelFromBranch(entries) || contextModelRef(ctx) || getFallbackModel();
  const stats = computeStats(entries, fallback);
  const dieselDisplay = stats.totalOutputTokens > 0 ? `🚗 ${stats.display}` : "🚗 --";

  // Use Pi's built-in extension status mechanism instead of replacing the whole footer.
  // This keeps Pi-owned model/thinking/context display in sync with core behavior.
  ctx.ui.setStatus?.("diesel-km", dieselDisplay);
}

// ── Extension ────────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  let currentModel: { provider?: string; model?: string } | undefined;

  pi.on("model_select", async (_event, ctx) => {
    currentModel = contextModelRef(ctx) || currentModel;
  });

  pi.on("session_start", async (_event, ctx) => {
    currentModel = contextModelRef(ctx) || currentModel;
    updateDieselStatus(ctx, () => currentModel);
  });

  pi.on("turn_end", async (_event, ctx) => {
    currentModel = contextModelRef(ctx) || currentModel;
    updateDieselStatus(ctx, () => currentModel);
  });

  pi.registerCommand("diesel-km", {
    description: "Show model-aware EcoLogits energy as 5L/100km diesel distance",
    handler: async (_args, ctx) => {
      const branch = ctx.sessionManager.getBranch() as SessionEntry[];
      const fallback = currentModelFromBranch(branch) || contextModelRef(ctx) || currentModel;
      const stats = computeStats(branch, fallback);

      if (stats.totalOutputTokens === 0) {
        ctx.ui.notify("No assistant messages yet (no output tokens to measure).", "warning");
        return;
      }

      const modelLines = stats.modelBreakdown.map((m) => [
        `  Model:  ${m.label}`,
        `    Output tokens: ${fmtToken(m.outputTokens)}`,
        `    Energy:        ${fmtEnergy(m.energyKwh)}`,
        `    Factor:        ${fmtFactor(m.factorKwhPerToken)}`,
        `    Diesel dist:   ${formatDistance(m.meters)}`,
        `    Source:        ${m.source}`,
      ].join("\n")).join("\n\n");

      const modelDataNote = stats.modelDataLoaded
        ? `Model metadata: ${ECOLOGITS_MODELS_JSON}`
        : `Model metadata unavailable (${MODEL_INDEX.error || "unknown"}); using fallback when needed.`;

      ctx.ui.notify([
        "Diesel-KM: Model-Aware Energy × Distance",
        "",
        `  Total tokens: ${fmtToken(stats.totalTokens)} (↑${fmtToken(stats.totalInputTokens)} / ↓${fmtToken(stats.totalOutputTokens)})`,
        `  Total energy: ${fmtEnergy(stats.totalEnergyKwh)}`,
        `  Diesel:       5L/100km car equivalent = ${stats.display}`,
        "",
        modelLines,
        "",
        "  EcoLogits request-energy port:",
        "    gpu_energy = output_tokens × (α·e^(β·batch)·active_params + γ) / 1000",
        "    request_energy = PUE × (server_energy + gpu_required_count × gpu_energy)",
        "    server_energy uses generation latency from model TPS/TTFT when available.",
        "",
        "  EcoLogits-derived calculation inputs:",
        `    ${modelDataNote}`,
        "    Provider PUE: mirrored from EcoLogits ecologits/tracers/utils.py PROVIDER_CONFIG_MAP.",
        `    Runtime constants: batch=${BATCH_SIZE}, quantization=${MODEL_QUANTIZATION_BITS}-bit, GPU=${GPU_MEMORY_GB}GB, server=${SERVER_GPUS} GPUs/${SERVER_POWER_KW}kW.`,
        "",
        "  Local comparison input:",
        "    Diesel reference: 5L/100km × 9.8 kWh/L = 0.49 kWh/km.",
        "  Energy-content comparison only; not lifecycle CO₂ or tailpipe-emissions equivalence.",
      ].join("\n"), "info");
    },
  });
}
