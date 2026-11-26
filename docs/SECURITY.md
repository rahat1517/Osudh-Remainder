# Security Review

Status: reviewed for the MVP (Phase 7). Re-review before each major release.

## Assets

1. Health data: medicines, dose history (sensitive personal data)
2. Identity: phone numbers, caregiver relationships
3. Prescription photos (in transit only)
4. Secrets: Anthropic API key, Supabase service credentials, Firebase service account
5. Availability of reminders (patient safety)

## Architecture and trust boundaries

```
Phone app ──HTTPS──► Supabase (Auth, PostgreSQL with RLS)      ← direct, per-user access
    │
    └──HTTPS + JWT──► Backend API ──► Anthropic API (prescription reading)
                          ▲
Scheduled job (privileged DB URL) ──► FCM (caregiver alerts)
```

## Threats and controls

| Threat | Control | Verified by |
|---|---|---|
| One user reads or edits another's data | Row-level security on every table; ownership triggers on medicines and dose logs | `tests/db/test_rls.py` |
| Caregiver access without consent | Links only via single-use, expiring, patient-created invites; direct inserts denied; revocable by either side | `tests/db/test_caregivers.py` |
| Caregiver escalates from view to edit | `is_caregiver_of(…, need_edit)` in insert/update policies; confirm function checks edit right | DB tests |
| Unauthenticated use of the paid AI endpoint | Supabase JWT required (JWKS or HS256, audience and issuer checked); production refuses to start without auth | `tests/test_security.py` |
| Cost abuse / denial of wallet | Per-user sliding-window limits (5/min, 30/h, 100/day), 15 MB upload cap | `tests/test_security.py` |
| AI misreads a prescription → wrong dose | Per-field confidence; rule-based verifier never raises confidence; user must review every uncertain field; no schedule without confirmation | verifier and app tests |
| Prompt injection via text in the photo | Output constrained to a fixed schema with no free-form actions; values are verified against the catalogue and rules; nothing executes from model output | design; schema tests |
| Location leak through photo metadata | Images re-encoded; EXIF/GPS stripped before sending | `tests/test_images.py` |
| Patient data in logs or error reports | Request bodies, query strings, cookies and auth headers scrubbed before Sentry; no PII in logs | `tests/test_security.py` |
| Patient data committed to git | Root-anchored ignore rules for data folders, images and PDFs blocked everywhere | `.gitignore`, review |
| Secret leakage | Secrets only in `.env`/CI secrets; service role used only by the server job | review |
| Account takeover via SMS OTP | Supabase OTP rate limits; short-lived sessions | Supabase configuration |
| Reminders silently stop | Offline-first cache, exact alarms, boot receiver, 7-day horizon with renewal notice | alarm tests |
| Data retention after deletion | `delete_my_account` cascades to all user data | DB tests |

## Operational requirements before launch

- [ ] Supabase: enable phone auth with an SMS provider; set OTP rate limits; enable asymmetric JWT
      signing keys; restrict the service role to the server
- [ ] Backend: `ENVIRONMENT=production`, `SUPABASE_URL` set (auth enforced), HTTPS only, single instance
      or shared rate-limit storage
- [ ] Store `ANTHROPIC_API_KEY`, `DATABASE_URL`, `FCM_SERVICE_ACCOUNT` as platform secrets
- [ ] Set a monthly spending limit on the Anthropic account
- [ ] Enable Supabase point-in-time backups
- [ ] Rotate keys if a laptop or CI secret is exposed

## Known limitations

- Rate limits are per process; use shared storage when running several instances.
- The drug catalogue is an unverified sample until the DGDA list is imported.
- OTP over SMS is phishable; consider adding device binding for caregivers later.

## Reporting a vulnerability

Email the maintainers (address to be added) with steps to reproduce. Please do not open public issues
for security problems.
