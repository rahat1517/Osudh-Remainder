# Drug catalogue seed data

> **`drugs_seed.csv` is not an official or verified list.**
> It is a small sample of common Bangladeshi brands for development and tests
> (`source=dev-seed`, `verified=false`). Manufacturers or strengths may be wrong.
> **Replace it with the official DGDA register before the app reaches patients.**
> The `unit_price_bdt` values are rough development estimates, not real MRPs: the app labels
> unverified prices "approximate", but they must be replaced with the DGDA maximum retail prices.

## Columns

| Column | Example | Required |
|---|---|---|
| `brand` | Seclo | yes |
| `strength` | 20 mg, 500 mg + 65 mg, 120 mg/5 ml | no (e.g. ORS) |
| `generic` | Omeprazole | yes |
| `form` | Tablet, Capsule, Suspension | yes |
| `manufacturer` | Square Pharmaceuticals | no |
| `source` | dev-seed, dgda-2026 | yes |
| `verified` | true / false | yes |
| `unit_price_bdt` | 6, 1.2, 35 (taka per tablet / capsule / sachet; per bottle for liquids) | no |

## Adding the official list

1. Download the registered-drugs list from the DGDA website and map it to the columns above.
2. Save it here, e.g. `dgda_2026.csv` (`source=dgda-2026`, `verified=true`).
3. Validate and generate SQL:
   ```bash
   cd backend
   uv run python -m app.drugs.importer ../database/seed/dgda_2026.csv --sql ../supabase/seed.sql
   ```
