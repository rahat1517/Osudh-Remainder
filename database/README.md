# Database

Supabase configuration and migrations live in the root **`supabase/`** folder, where the Supabase CLI
expects them. This folder holds the drug catalogue sources.

## Drug catalogue (Phase 1)

```
database/seed/drugs_seed.csv              source CSV; edit here
        │  importer (validate, de-duplicate, normalise names)
        ▼
supabase/seed.sql                         generated; do not edit by hand
supabase/migrations/…_create_drugs.sql    table, trigram indexes, row-level security
```

> The current list is a development sample (46 entries, unverified). See
> [seed/README.md](seed/README.md) for adding the official list.

Regenerate the SQL after changing a CSV (CI fails if it is stale):

```bash
cd backend
uv run python -m app.drugs.importer ../database/seed/drugs_seed.csv --sql ../supabase/seed.sql
```

### Access rules

- Everyone can **read** `drugs`; it is public reference data, not patient data.
- No app client can **write** it. Only the service role (backend, importer) can.

## Running Supabase locally

Requires the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
and Docker.

```bash
npx supabase start     # local database, auth and storage
npx supabase status    # prints URLs and keys for backend/.env
npx supabase stop
```

## Planned tables

| Table | Phase |
|---|---|
| `drugs` ✅ | 1 |
| `profiles`, `prescriptions`, `medicines`, `schedules` | 4 |
| `dose_logs` | 5 |
| `caregivers`, `notifications` | 6 |
| `consents` | 11 |

Every table has row-level security enabled.
