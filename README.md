# Metabolomics Subtypes Explorer

A statically deployable Next.js research portal for exploring differential metabolite expression across PTSD, depressive, and cognitive subtype comparisons. The current v12 release contains 385 metabolites, six comparison definitions, biological annotations, and PubMed references.

## Product capabilities

- Cross-comparison matrix with search, filtering, sorting, pagination, and CSV export
- Per-comparison volcano plots
- Metabolite detail views with identifiers, effect sizes, p-values, FDR values, mechanisms, and citations
- Disorder- and pathway-oriented literature browsing
- Responsive layouts and keyboard-accessible interaction

## Local development

Requirements: Node.js 20+ and Python 3 with pandas when regenerating data.

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Quality checks

```bash
npm test          # data contract and ESLint
npm run build     # TypeScript and static production export
npm run check     # all checks above
```

The production export is written to `out/` and is configured in `next.config.ts`.

## Data pipeline

The browser consumes the versioned JSON release in `src/data/metabolites_data.json`. Rebuild and validate it with:

```bash
python3 scripts/prepare_data.py
npm run validate:data
```

See [`data/README.md`](data/README.md) for the schema, release contract, missing-value policy, and migration guidance. Source comparison files are mapped in `scripts/prepare_data.py`; the script now fails on missing inputs by default.

## Interpretation limits

- Association and differential-expression results are not proof of causality or clinical utility.
- A missing comparison is displayed as unavailable, never converted to a zero effect.
- Some references support a pathway or metabolite class rather than the exact compound. Scientific review should preserve that evidence level.
- Comparison labels must remain aligned with the analysis definitions in the source release.

## Deployment

`next.config.ts` uses `output: "export"`, so the generated `out/` directory can be served by any static host, including Vercel. No application database or server runtime is required for this read-only release.
