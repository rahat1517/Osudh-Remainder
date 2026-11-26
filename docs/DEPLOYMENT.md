# Deployment

## Components

| Component | Where | Notes |
|---|---|---|
| Database, auth | Supabase project (region: Singapore or Mumbai, closest to Bangladesh) | Apply `supabase/migrations`, load `supabase/seed.sql` |
| Backend API | Any container host (Fly.io, Railway, Render, Cloud Run) | `backend/Dockerfile`, one instance (in-process rate limits) |
| Missed-dose job | GitHub Actions schedule (`.github/workflows/missed-dose-alerts.yml`) or the host's cron | every 5 minutes |
| Push | Firebase project (Cloud Messaging) | service account for the job, app config via `--dart-define` |

## Supabase

```bash
npx supabase link --project-ref <ref>
npx supabase db push                                   # apply migrations
psql "$DATABASE_URL" -f supabase/seed.sql              # drug catalogue
```

Dashboard: enable Phone auth with an SMS provider, set OTP rate limits, enable JWT signing keys.
Storage (only if collecting training data, Phase 11): create a **private** bucket `training-examples`
with no public access and no client policies; only the service role writes and reads it.

## Backend

Environment variables (see `.env.example`):

| Variable | Required | Purpose |
|---|---|---|
| `ENVIRONMENT=production` | yes | enforces authentication |
| `SUPABASE_URL` | yes | token verification (JWKS) |
| `SUPABASE_JWT_SECRET` | legacy projects | HS256 token verification |
| `ANTHROPIC_API_KEY` | yes | prescription reading |
| `SENTRY_DSN` | optional | error monitoring (scrubbed) |
| `READER_MODE`, `LOCAL_READER_URL`, `LOCAL_READER_MODEL` | optional | `hybrid` routes to a self-hosted model first (Phase 11) |
| `DATABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `TRAINING_PEPPER` | optional | collect consented training examples (Phase 11) |

```bash
docker build -t oshudh-api -f backend/Dockerfile .
docker run -p 8000:8000 --env-file backend/.env oshudh-api
```

Put it behind HTTPS. Check `GET /health`.

## Job secrets (GitHub)

Repository → Settings → Secrets → Actions: `DATABASE_URL` (Supabase connection string with a
privileged role) and `FCM_SERVICE_ACCOUNT` (JSON contents). For SMS/voice reminders also
`SMS_GATEWAY_URL`, `SMS_API_KEY`, `SMS_SENDER_ID`, `VOICE_GATEWAY_URL`, `VOICE_API_KEY`. If your provider
uses different field names, add an adapter next to `backend/app/escalation/gateways.py`.

## App

See [release/play-store.md](release/play-store.md).
