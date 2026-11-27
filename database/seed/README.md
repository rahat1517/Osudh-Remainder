# Drug catalogue seed data

> **`drugs_seed.csv` is not an official or verified list.**
> 21,592 Bangladeshi brands with prices from the public "Assorted Medicine Dataset of Bangladesh"
> (collected from medex.com.bd in 2023; `source=medex-2023`), built by
> `database/sources/convert_medex_2023.py`. Prices are 2023 retail prices, not checked against the
> DGDA list (`verified=false`), so the app calls them approximate.
> **Replace or verify them against the official DGDA register before the app reaches patients.**
>
> Row N is drug id N: medicines saved by users point at these ids. Only add rows at the end;
> never reorder or delete rows (the converter keeps the first rows in place).

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
| `unit_price_bdt` | 6, 1.2, 35 (taka per tablet / capsule; for a pack, the pack's price) | no |
| `pack` | 60 ml bottle, 10 gm tube (empty when the price is per piece) | no |

## Adding the official list

1. Download the registered-drugs list from the DGDA website and map it to the columns above.
2. Save it here, e.g. `dgda_2026.csv` (`source=dgda-2026`, `verified=true`).
3. Validate and generate SQL:
   ```bash
   cd backend
   uv run python -m app.drugs.importer ../database/seed/dgda_2026.csv --sql ../supabase/seed.sql
   ```
