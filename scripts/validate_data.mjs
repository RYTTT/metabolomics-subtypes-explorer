import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const sourcePath = resolve(root, "data/metabolites_data.json");
const clientPath = resolve(root, "src/data/metabolites_data.json");
const releasePath = resolve(root, "src/data/release.json");

const comparisonKeys = [
  "Depressive_vs_Control",
  "Cognitive_vs_Control",
  "MildPTSD_vs_Control",
  "SeverePTSD_vs_Control",
  "MildPTSD_vs_SeverePTSD",
  "CogPos_vs_CogNeg",
];
const requiredFields = [
  "chem_id",
  "chemical_name",
  "super_pathway",
  "sub_pathway",
  "disorders",
  "mechanism",
  "references",
  "comparisons",
];

const [sourceBuffer, clientBuffer, releaseBuffer] = await Promise.all([
  readFile(sourcePath),
  readFile(clientPath),
  readFile(releasePath),
]);
const data = JSON.parse(sourceBuffer.toString("utf8"));
const release = JSON.parse(releaseBuffer.toString("utf8"));
const errors = [];

if (!Array.isArray(data)) errors.push("Dataset root must be an array.");
if (!sourceBuffer.equals(clientBuffer)) errors.push("data/ and src/data/ dataset copies differ.");
if (data.length !== release.record_count) {
  errors.push(`Release metadata expects ${release.record_count} records; found ${data.length}.`);
}

const ids = new Set();
const observedMissing = new Set();
const knownMissing = new Set(
  release.known_missing_comparisons.map(({ chem_id, comparison }) => `${chem_id}:${comparison}`),
);

for (const [index, metabolite] of data.entries()) {
  const location = `record ${index + 1}`;
  for (const field of requiredFields) {
    if (!(field in metabolite)) errors.push(`${location} is missing ${field}.`);
  }
  if (!metabolite.chem_id) errors.push(`${location} has an empty chem_id.`);
  if (ids.has(metabolite.chem_id)) errors.push(`Duplicate chem_id: ${metabolite.chem_id}.`);
  ids.add(metabolite.chem_id);

  for (const key of comparisonKeys) {
    const comparison = metabolite.comparisons[key];
    if (!comparison) {
      observedMissing.add(`${metabolite.chem_id}:${key}`);
      continue;
    }
    for (const pField of ["P.Value", "adj.P.Val"]) {
      const value = comparison[pField];
      if (!Number.isFinite(value) || value < 0 || value > 1) {
        errors.push(`${metabolite.chem_id}.${key}.${pField} must be between 0 and 1.`);
      }
    }
    if (!Number.isFinite(comparison.logFC)) {
      errors.push(`${metabolite.chem_id}.${key}.logFC must be finite.`);
    }
  }

  for (const reference of metabolite.references) {
    if (!/^\d+$/.test(reference.pmid) || !reference.url.includes(reference.pmid)) {
      errors.push(`${metabolite.chem_id} has an invalid PMID reference: ${reference.pmid}.`);
    }
  }
}

for (const missing of observedMissing) {
  if (!knownMissing.has(missing)) errors.push(`Undocumented missing comparison: ${missing}.`);
}
for (const missing of knownMissing) {
  if (!observedMissing.has(missing)) errors.push(`Stale known-missing declaration: ${missing}.`);
}

if (errors.length) {
  console.error(`Data validation failed with ${errors.length} issue(s):`);
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  const digest = createHash("sha256").update(sourceBuffer).digest("hex").slice(0, 12);
  console.log(
    `Validated ${data.length} metabolites, ${comparisonKeys.length} comparisons, `
      + `${observedMissing.size} documented missing values (sha256:${digest}).`,
  );
}
