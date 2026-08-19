# Data release contract

`metabolites_data.json` is the canonical, versioned static data release used by the explorer. The identical copy in `src/data/` is imported by the statically exported application.

## Rebuild

Run from the repository root:

```bash
python3 scripts/add_effect_sizes.py
python3 scripts/prepare_data.py
npm run validate:data
```

The preparation command resolves the repository root from its own location. A different root can be provided with `--base-dir`. Missing comparison sources fail the build unless an intentionally partial release uses `--allow-missing`.

## Standardized effect sizes

Each comparison stores `effect_size` (Cohen's d), calculated from its t-statistic as
`d = t / sqrt(N_eff)`, where `N_eff = n1 * n2 / (n1 + n2)`. Cohort sizes are:

- Depressive vs Control: 29 vs 444
- Cognitive vs Control: 84 vs 444
- Mild PTSD vs Control: 81 vs 444
- Severe PTSD vs Control: 139 vs 444
- Mild vs Severe PTSD: 81 vs 139
- CogPos vs CogNeg: 143 vs 180

Hedges' g applies the small-sample correction
`J = 1 - 3 / (4 * (n1 + n2 - 2) - 1)` and is stored as `hedges_g = effect_size * J`.

`scripts/add_effect_sizes.py` adds both values to all 37 CSV files containing differential-analysis t-statistics, including original, v12, production, causal, and robustness outputs. Run it with `--check` to verify existing values without rewriting them. Because these values derive from moderated t-statistics, they should be interpreted as t-derived standardized effect estimates rather than raw pooled-SD estimates.

## Validation and provenance

- `metabolites.schema.json` documents the serialized record shape.
- `src/data/release.json` records the public release date, expected counts, and intentionally unavailable comparisons.
- `npm run validate:data` checks duplicate identifiers, p-value ranges, PMID links, copy consistency, expected counts, missing-comparison declarations, and recomputes every effect size from its t-statistic and cohort sizes.
- Biological annotations may describe a metabolite class or pathway rather than direct compound-specific evidence. Citation interpretation must preserve that distinction during scientific review.

The app is intentionally backed by a static release because the public data is read-only. If collaborative curation or multiple releases become operational requirements, migrate the same contract to normalized PostgreSQL tables for metabolites, comparisons, results, references, releases, and import runs.
