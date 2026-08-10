# Data release contract

`metabolites_data.json` is the canonical, versioned static data release used by the explorer. The identical copy in `src/data/` is imported by the statically exported application.

## Rebuild

Run from the repository root:

```bash
python3 scripts/prepare_data.py
npm run validate:data
```

The preparation command resolves the repository root from its own location. A different root can be provided with `--base-dir`. Missing comparison sources fail the build unless an intentionally partial release uses `--allow-missing`.

## Validation and provenance

- `metabolites.schema.json` documents the serialized record shape.
- `src/data/release.json` records the public release date, expected counts, and intentionally unavailable comparisons.
- `npm run validate:data` checks duplicate identifiers, p-value ranges, PMID links, copy consistency, expected counts, and missing-comparison declarations.
- Biological annotations may describe a metabolite class or pathway rather than direct compound-specific evidence. Citation interpretation must preserve that distinction during scientific review.

The app is intentionally backed by a static release because the public data is read-only. If collaborative curation or multiple releases become operational requirements, migrate the same contract to normalized PostgreSQL tables for metabolites, comparisons, results, references, releases, and import runs.
