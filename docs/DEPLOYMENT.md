# Deployment

## Components

| Component | Where | Notes |
|---|---|---|
| Database, auth | Supabase project (region: Singapore or Mumbai, closest to Bangladesh) | Apply `supabase/migrations`, load `supabase/seed.sql` |
| Backend API | Any container host (Fly.io, Railway, Render, Cloud Run) | `backend/Dockerfile`, one instance (in-process rate limits) |
| Missed-dose job | GitHub Actions schedule (`.github/workflows/missed-dose-alerts.yml`) or the host's cron | every 5 minutes; off until the `ALERTS_ENABLED=true` repository variable is set |
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
| `ANTHROPIC_API_KEY` | optional | Claude reads prescriptions (paid). Without it the server's own OCR model reads them |
| `GEMINI_API_KEY`, `GEMINI_MODEL` | optional | free key from aistudio.google.com: Gemini reads photos the own model is unsure of, only for users who allowed it in the app, with personal lines blacked out first. Default model `gemini-2.5-flash` |
| `SENTRY_DSN` | optional | error monitoring (scrubbed) |
| `READER_MODE`, `LOCAL_READER_URL`, `LOCAL_READER_MODEL` | optional | `hybrid` routes to a self-hosted model first (Phase 11) |
| `DATABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `TRAINING_PEPPER` | optional | collect consented training examples (Phase 11). `DATABASE_URL` logs in as `oshudh_backend` (can only check consent and add examples) through the pooler: `postgresql://oshudh_backend.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:6543/postgres?sslmode=require`. Keep `TRAINING_PEPPER` unchanged once set |

```bash
docker build -t oshudh-api -f backend/Dockerfile .
docker run -p 8000:8000 --env-file backend/.env oshudh-api
```

Put it behind HTTPS. Check `GET /health`.

### Render (one click)

`render.yaml` describes the service. In Render: **New → Blueprint → this repository**, enter
`ANTHROPIC_API_KEY` when asked (and `SUPABASE_JWT_SECRET` only for legacy-secret projects), then
**Apply**. Render builds `backend/Dockerfile`, runs it in Singapore behind HTTPS, checks `/health`,
and redeploys on every push to `main`. Use the service URL as the app's `BACKEND_URL`.

## Running at no cost

| Part | Free option | Limit |
|---|---|---|
| Supabase | Free plan | pauses after a week with no activity |
| Backend | Render `plan: free` (default in `render.yaml`) | sleeps after 15 min idle; first request ~1 min |
| Prescription reading | leave `ANTHROPIC_API_KEY` unset; add a free `GEMINI_API_KEY` | the server's own OCR model reads, Gemini helps with hard photos for users who allow it |
| Reminders and alarms | on the phone, offline | none |
| Caregiver push alerts | Firebase Cloud Messaging is free; the job needs Actions minutes | private repo: 2,000 min/month is not enough for a 5-minute job; a public repo is free |
| SMS / voice calls | leave off | each message costs money |
| Distribution | share the APK directly for the pilot | Play Store needs a one-time $25 developer fee |

## Job secrets (GitHub)

Repository → Settings → Secrets → Actions: `DATABASE_URL` (Supabase connection string with a
privileged role) and `FCM_SERVICE_ACCOUNT` (JSON contents). For SMS/voice reminders also
`SMS_GATEWAY_URL`, `SMS_API_KEY`, `SMS_SENDER_ID`, `VOICE_GATEWAY_URL`, `VOICE_API_KEY`. If your provider
uses different field names, add an adapter next to `backend/app/escalation/gateways.py`.

## App

Pilot builds: `.github/workflows/pilot-apk.yml` builds on every push to `main` that changes the app
(or by hand). Each build:

- is published as the `pilot` GitHub release (universal APK, one fixed link);
- with the `SUPABASE_SERVICE_ROLE_KEY` repository secret set, uploads one APK per processor type
  plus `latest.json` to the public Supabase bucket `app-releases`. Installed pilot builds read
  `latest.json` at start and show "নতুন সংস্করণ এসেছে" with a download button. Android then asks
  the user to tap Install; apps from outside the Play Store cannot update silently.

All pilot APKs share one signing key and a rising version code, so each one installs over the
previous one and keeps the user's data. Store release: see [release/play-store.md](release/play-store.md).
