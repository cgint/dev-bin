import {
  buildProjectionPrompt,
  selectEpisode,
  serializeEpisode,
  serializeRepairContext,
  type RepairEntry,
} from "../shared-attention-repair";

type Fixture = {
  name: string;
  provenance: string;
  purpose: string;
  attentionTarget: string[];
  entries: RepairEntry[];
};

function option(args: string[], name: string): string | undefined {
  const index = args.indexOf(name);
  return index === -1 ? undefined : args[index + 1];
}

function usage(): never {
  console.error("Usage: bun extensions/lab/playground.ts [--budget N] [--candidate PATH]");
  process.exit(2);
}

const args = Bun.argv.slice(2);
const budgetValue = option(args, "--budget") ?? "30";
const budget = Number.parseInt(budgetValue, 10);
if (!Number.isInteger(budget) || budget < 1 || budget > 100) usage();
if (args.some((arg) => !["--budget", "--candidate", budgetValue, option(args, "--candidate")].includes(arg))) usage();

const fixture = await Bun.file(
  new URL("../fixtures/user-correction-over-implementation.json", import.meta.url),
).json() as Fixture;
const selected = selectEpisode(fixture.entries, budget);
const transcript = serializeEpisode(selected.entries);
const repairContext = serializeRepairContext(selected.entries);
const candidatePath = option(args, "--candidate");
const candidate = candidatePath ? await Bun.file(candidatePath).text() : undefined;

console.log(`# Shared attention repair playground: ${fixture.name}`);
console.log(`provenance: ${fixture.provenance}`);
console.log(`purpose: ${fixture.purpose}`);
console.log("\n## Attention target (human-authored learning target)");
for (const target of fixture.attentionTarget) console.log(`- ${target}`);
console.log("\n## Inspected conversation");
console.log(transcript);
console.log("\n## Actor-separated context sent to the model");
console.log(repairContext);
console.log("\n## Prompt sent to the model");
console.log(buildProjectionPrompt(repairContext, 300));
if (candidate !== undefined) {
  console.log("\n## Candidate output under inspection");
  console.log(candidate.trim());
}
