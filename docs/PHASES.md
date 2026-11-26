# Roadmap

The project is split into twelve phases. Each phase lists its goal, dependencies, tasks and exit
criteria. Work happens on one branch per phase; a phase is done when its exit criteria are verified
and reported.

Legend: ✅ done · ⏳ blocked on an external input · ⬜ not started

## Overview

| Phase | Name | Area | Estimate | Status |
|---|---|---|---|---|
| **0** | Foundation and setup | all | 1 week | ✅ |
| **1** | Bangladeshi drug catalogue | database, backend | 1-2 weeks | ✅ (official data ⏳) |
| **2** | Prescription reader and verifier (AI) | backend | 2-3 weeks | ✅ (live eval ⏳) |
| **3** | Schedule engine | backend, app | 1 week | ✅ |
| **4** | App: onboarding, scan and confirm | app | 2-3 weeks | ✅ (device test ⏳) |
| **5** | Offline alarm engine and Bangla voice | app | 2 weeks | ✅ (device test ⏳) |
| **6** | Caregiver mode | app, backend | 1-2 weeks | ✅ (Firebase setup ⏳) |
| **7** | Testing, pilot and Play Store | all | 2-3 weeks | ✅ (pilot and store ⏳) |
| | **MVP launch** | | **~3-4 months** | |
| **8** | Bangla AI assistant | backend, app | 2 weeks | ✅ (live eval ⏳) |
| **9** | Learning, refills and Ramadan mode | backend, app | 2 weeks | ✅ |
| **10** | SMS and voice-call escalation | backend | 1-2 weeks | ⬜ |
| **11** | Data flywheel and self-hosted model (hybrid) | ml, backend | 4-6 weeks | ⬜ |

Estimates assume one developer working with an AI assistant.

```
0 ──► 1 ──► 2 ──► 3 ──► 4 ──► 5 ──► 6 ──► 7 (MVP)
                              │
                              └──► 8 ──► 9 ──► 10 ──► 11
```

## Technical decisions

| Topic | Decision | Reason |
|---|---|---|
| Mobile app | Flutter, Android first | One codebase; most phones in Bangladesh run Android |
| Backend | Python + FastAPI | Best ecosystem for AI and ML; same language as `ml/` |
| Database and auth | Supabase (PostgreSQL, phone OTP, storage) | Free to start; row-level security |
| Prescription reading | Claude vision + structured output | Strong at handwriting; later hybrid with a local model |
| Schedule computation | **Rule-based, not AI** | Dose timing must be exact and fully testable |
| Alarms | Android AlarmManager (local) | Offline and reliable |
| Push notifications | Firebase Cloud Messaging | Caregiver alerts |
| API errors | Stable codes + English messages; the app localizes | Clients never parse prose |

---

## Phase 0: Foundation and setup ✅

**Goal:** a working skeleton of every component.

- [x] Repository on GitHub
- [ ] Branch protection on `main` (GitHub settings; owner action)
- [x] Backend: FastAPI project, `/health`, settings from `.env`, pytest, ruff
- [x] App: Flutter project, Bangla font (Hind Siliguri), theme, Bangla/English localization
- [x] Supabase local configuration
- [ ] Supabase cloud project (owner action, before production)
- [x] GitHub Actions CI: backend lint and tests, Flutter format, analyze and tests, debug APK build
- [x] `CONTRIBUTING.md`

**Exit criteria:** ✅ `GET /health` returns ok · ✅ app starts with Bangla text · ✅ CI green

---

## Phase 1: Bangladeshi drug catalogue ✅ (official data ⏳)

**Goal:** a reliable catalogue for verifying names read from prescriptions and for autocomplete.

- [x] Schema: `drugs` (brand, generic, strength, form, manufacturer, source, verified)
- [ ] Official source: the DGDA register, with usage terms checked. **Owner action:** the DGDA site
      is not reachable from the build environment. A 46-entry *unverified* development seed is used
      until then.
- [x] Importer: CSV → validated, de-duplicated, normalised → idempotent `supabase/seed.sql`
      (CI fails if the SQL is stale)
- [x] Search: `pg_trgm` indexes in the database; rapidfuzz two-stage matching in the backend
- [x] Normalisation: dosage-form words, units, Bangla digits, OCR digit/letter confusion,
      abbreviations, brands with digits in the name (`Cef-3`)
- [x] API: `GET /drugs/search`, `POST /drugs/match`, `GET /drugs/{id}`
- [x] Tests: 56 realistic misspellings

**Exit criteria:**
- ⏳ 1,000+ common brands (38 today, waiting for official data)
- ✅ ≥ 90% correct on the misspelling set: **56/56 (100%), and no wrong answer marked high**
- ✅ Search < 200 ms: **16-34 ms on a 30,000-drug synthetic catalogue**

---

## Phase 2: Prescription reader and verifier ✅ (live eval ⏳)

**Goal:** prescription photo → list of medicines with a confidence for every field.

- [x] Output schema with per-field confidence (name, strength, dose, timing, duration)
- [x] **Agent 1 (reader):** Claude vision with structured output, adaptive thinking at high effort,
      server-side refusal fallback
- [x] Prompt covering Bangladeshi notation (Bangla digits, `1+0+1`, `½`, OD/BD/TDS/QID/HS, AC/PC,
      before/after food, "continue", SOS)
- [x] **Agent 2 (verifier, rule-based):** catalogue matching, dose-pattern and duration validation,
      confidence caps on poor images. Final confidence never exceeds the AI's own.
- [x] Image checks: format, size, minimum resolution; "not a prescription" detection
- [x] Privacy: no schema fields for patient identity; EXIF/GPS stripped; images never stored
- [x] API: `POST /prescriptions/extract` with error codes
- [x] Eval set: 10 fictional prescriptions × clean/photo variants (31 medicines), generator, billed
      runner gated behind `--yes`, scoring self-test
- [ ] More cases, including consented real handwritten prescriptions with personal data removed

**Exit criteria:**
- ⏳ Printed prescriptions: name ≥ 95%, dose ≥ 95% correct (run the eval with an API key)
- ⏳ Handwritten prescriptions: ≥ 98% of high-confidence fields correct (needs real samples)
- ⏳ Most misread fields marked medium or low

---

## Phase 3: Schedule engine ✅

**Goal:** confirmed medicines → exact reminder times, identical on server and phone.

- [x] Language-neutral specification: [SCHEDULE_SPEC.md](SCHEDULE_SPEC.md)
- [x] Dose patterns (2-4 slots, Bangla digits, fractions), interval dosing (every N hours), weekly
      medicines, as-needed medicines (never scheduled)
- [x] Meal-time offsets (before −30, after +15, empty stomach −60 min; configurable), bedtime,
      doses after midnight
- [x] Course length by dose count: a course confirmed in the afternoon keeps every dose
- [x] Reminder grouping that never delays a dose
- [x] Python engine and `POST /schedules/generate` (Asia/Dhaka, error codes)
- [x] Dart engine for offline use
- [x] 38 hand-derived conformance vectors run by both implementations
- [x] Property-based tests (Hypothesis); verified once at 5,000 examples per property
- [x] Differential test: 2,000 random cases, Python and Dart must agree exactly (CI job)

**Exit criteria:** ✅ all tests pass (141 backend, 58 app, 2,000-case parity) · ✅ Asia/Dhaka

---

## Phase 4: App onboarding, scan and confirm ✅ (device test ⏳)

**Goal:** a user can install the app and confirm a prescription.

- [x] Schema: `profiles` (auto-created on sign-up, meal times), `prescriptions` (draft → confirmed),
      `medicines`, view `active_medicines`, function `confirm_prescription`; row-level security.
      Dose times are derived by the schedule engine, not stored (single source of truth).
- [x] 14 database tests on real PostgreSQL with a Supabase auth shim (CI job): isolation between users,
      ownership checks, only confirmed medicines active, constraints, cascade delete
- [x] Phone login (Supabase OTP, SMS autofill hint); Bangladeshi number validation incl. Bangla digits
- [x] Demo mode without Supabase (in-memory data, code 123456) for development
- [x] Camera/gallery capture → `POST /prescriptions/extract` → confirm screen
- [x] **Confirm screen:** medium fields amber, low fields red; each must be confirmed ("Looks right") or
      edited; Confirm stays disabled until every visible field is reviewed and valid
- [x] Every backend error and notice code localized in Bangla and English (`spec/api/codes.json`,
      checked by backend and app tests)
- [x] API contract fixture shared by backend and app tests
- [x] Medicine-name autocomplete from the catalogue
- [x] Manual entry, home screen with today's grouped reminders and the next dose, medicine list with stop
- [x] Large text and touch targets, simple Bangla

**Exit criteria:**
- ⏳ First prescription confirmed within 3 minutes (end-to-end flow automated; needs a usability test)
- ✅ No schedule without confirmation (enforced in the app, the repository and the database view)
- ✅ Users cannot see each other's data (RLS tests)

---

## Phase 5: Offline alarm engine and Bangla voice ✅ (device test ⏳)

**Goal:** alarms fire on time without internet, even with the phone locked.

- [x] Offline cache on the phone (medicines, settings, dose log, snooze counts); the app keeps working
      from it when the server is unreachable
- [x] Alarm planner (pure, tested): 7-day horizon from the Dart schedule engine, stable notification ids,
      handled doses dropped, cap of 150 alarms, an "open the app" notice before the horizon runs out
- [x] Exact alarms (`alarmClock` mode; inexact fallback when the permission is denied)
- [x] Full-screen alarm over the lock screen (`showWhenLocked`, `turnScreenOn`, full-screen intent):
      time, medicines, amounts, large buttons
- [x] Taken / Snooze 10 min / Skip, from the alarm screen or directly from the notification, including
      a background handler while the app is closed; at most 3 snoozes
- [x] Bangla text-to-speech (bn-BD, falling back to bn-IN), slower speech rate
- [x] Alarms restored after reboot and app update (boot receiver); re-synced on every app start,
      refresh and alarm action
- [x] Battery and autostart guidance for Xiaomi/Redmi/POCO, Oppo/Realme/OnePlus, Vivo/iQOO, Samsung,
      Huawei/Honor; standard Android screen for Symphony, Walton and others
- [x] `dose_logs` table with RLS (2 more database tests); offline log uploaded when online
- [ ] Real-device testing (Xiaomi, Realme and at least one more brand). **Owner action.**

**Exit criteria:**
- ⏳ Fires on time in airplane mode with the phone locked after 8 hours (needs a real phone; the
  scheduling path is covered by tests and the APK build)
- ⏳ Survives restart (boot receiver configured; verify on a phone)
- ⏳ Tested on at least 3 brands

Play Store note: the app uses `SCHEDULE_EXACT_ALARM` (user-granted) rather than `USE_EXACT_ALARM`,
and `USE_FULL_SCREEN_INTENT`; both need a declaration in the Play Console (Phase 7).

---

## Phase 6: Caregiver mode ✅ (Firebase setup ⏳)

**Goal:** family members see the schedule and are alerted about missed doses.

- [x] Schema: `caregiver_links` (view / edit), single-use `caregiver_invites` (8-character codes
      without look-alike characters, 24-hour expiry), `push_tokens`, `missed_dose_alerts`
- [x] Consent: access only through a patient-created invite; links cannot be inserted directly;
      either side can revoke (`revoke_caregiver_link`)
- [x] RLS: caregivers read the patient's profile, prescriptions, medicines and dose log; edit caregivers
      may add and confirm prescriptions for the patient (10 database tests)
- [x] Missed-dose detection with the Python schedule engine (30-minute grace, 6-hour lookback)
- [x] Alert job: one alert per missed dose, grouped by time, in the caregiver's language (Bangla digits
      in Bangla), invalid push tokens removed; end-to-end test on PostgreSQL
- [x] FCM HTTP v1 notifier (service account); scheduled workflow every 5 minutes, inactive until secrets
      are set
- [x] App: family screen (invite, accept, revoke), caregiver dashboard (taken / skipped / missed / due /
      upcoming), add a prescription for the patient with edit permission, push-token registration,
      alert notification channel
- [ ] Firebase project and secrets (`DATABASE_URL`, `FCM_SERVICE_ACCOUNT`, app `FIREBASE_*` defines).
      **Owner action.**

**Exit criteria:**
- ✅ Caregiver alerted within 35 minutes of a missed dose (30-minute grace + 5-minute job interval),
  verified in the end-to-end job test; live delivery needs the Firebase setup
- ✅ No access without consent (database tests)

---

## Phase 7: Security, release readiness, pilot ✅ (pilot and store ⏳)

**Goal:** validate with real users and release safely.

- [x] API authentication: Supabase JWTs verified (JWKS ES256/RS256 and legacy HS256; audience, issuer,
      expiry); production refuses to start without auth
- [x] Per-user sliding-window rate limits on the AI endpoint (`429 rate_limited` with `Retry-After`)
- [x] Error monitoring (optional Sentry) with request bodies, query strings, cookies and auth headers
      scrubbed; request IDs
- [x] In-app account deletion (`delete_my_account`, cascades to all data; 2 database tests)
- [x] Settings screen: privacy summary, sign out, delete account
- [x] Privacy policy (English and Bangla) and terms of use: drafts for legal review (`docs/legal/`)
- [x] Security review with threat model and controls (`docs/SECURITY.md`)
- [x] Backend Docker image (non-root, health check) and CI job that builds and starts it
- [x] Android release signing via git-ignored `key.properties`
- [x] End-to-end API test: sign in → read → review → schedule
- [x] Play Store guide: listing (bn/en), health/exact-alarm/full-screen declarations, data safety form,
      release tracks (`docs/release/play-store.md`); deployment guide (`docs/DEPLOYMENT.md`)
- [x] Pilot plan with metrics, procedure and stop criteria (`docs/release/pilot-plan.md`)
- [ ] **Owner actions:** legal review, hosting, Supabase/Firebase production projects, Play Console
      account, upload key, pilot with 20-50 users

**Exit criteria:** ⏳ alarm reliability ≥ 99% in the pilot · ⏳ crash-free sessions ≥ 99% ·
⏳ Play Store review passed (all require the pilot and a Play Console account)

---

## Phase 8: Bangla AI assistant ✅ (live eval ⏳)

- [x] `POST /assistant/chat`: Claude with client-side tools on the stateless Messages API (no hosted
      conversation storage for health data); low effort for chat latency; prompt caching on the
      system prompt; server-side refusal fallback; tool loop capped at 6 rounds
- [x] Read-only tools: today's/tomorrow's schedule (schedule engine), medicine list, catalogue lookup
- [x] Changes are only proposed (`propose_stop_medicine`, `propose_change_meal_time`) and applied by
      the app after the user taps Confirm
- [x] Safety: rule-based emergency detection in Bangla and English (cardiac, breathing, consciousness,
      overdose/poisoning, allergy, self-harm, bleeding) answered with fixed 999 guidance before the
      model, and even when the AI is unavailable; prompt forbids dose advice and diagnosis
- [x] Eval: 100 cases; emergency detection and false positives tested offline (the eval caught three
      missed phrasings and a false positive on বিষণ্ণ, all fixed and kept as regression tests);
      live runner with deterministic and Claude-judge grading
- [x] App: chat screen, Bangla voice input (speech-to-text), spoken replies, emergency call button,
      action cards with Confirm
- [ ] Run the live eval with an API key. **Owner action.**

**Exit criteria:** ⏳ 100% on the safety eval (emergency part ✅ offline, dose-change part needs the
live run) · ⏳ ≥ 90% correct on common questions

---

## Phase 9: Learning, refills and Ramadan mode ✅

- [x] Meal-time learning: when doses for a meal were taken at least 20 minutes late (or early) on 3+
      days in the last week, the home screen proposes moving that meal by the median; applied only on "Yes"
- [x] Refills: tablets on hand entered per medicine; remaining = count minus doses scheduled since;
      "about N days left" in the list; home warning and a notification at 10:00 three days before running
      out (not when the course ends first)
- [x] Ramadan mode: sehri (Fajr, sun 18° below the horizon) and iftar (sunset) computed on the phone for
      8 divisional cities; matches 48 reference values from the Python `astral` library within 2 minutes
      (`spec/ramadan/vectors.json`); breakfast moves to sehri, the iftar meal is placed so even
      before-meal doses fall at or after sunset; medicines with doses inside fasting hours are listed for
      the doctor, never moved; previous times restored when turned off
- [x] Adherence report for the last 7 days (overall and per medicine), shareable as a PDF for the doctor
- [x] Duplicate-therapy warning (shared active ingredient, including combinations and salt names) on the
      home and confirm screens; the catalogue generic is stored with each medicine
- [x] Schema: `generic`, `pills_on_hand`, `pills_counted_at`, profile `district`, `ramadan_mode`;
      `active_medicines` recreated to include the new columns

**Exit criteria:** ✅ no suggestion takes effect without the user's "Yes" (tests) · ✅ Ramadan times
checked for Dhaka, Chattogram, Sylhet and five more divisional cities

---

## Phase 10: SMS and voice-call escalation ⬜

- [ ] Bangladeshi SMS gateway integration
- [ ] Automated voice calls with a recorded Bangla message
- [ ] Escalation rules: alarm → 30 min → SMS/call → caregiver
- [ ] Feature-phone mode: caregiver manages the schedule, patient receives calls/SMS
- [ ] Cost controls: daily limits, premium tier
- [ ] Opt-in and opt-out

**Exit criteria:** ≥ 95% of SMS and calls delivered on time · monthly cost per user tracked and capped

---

## Phase 11: Data flywheel and self-hosted model ⬜

**Depends on:** Phase 7 and 1,000-3,000 confirmed prescriptions

- [ ] Consent flow for using prescriptions to improve the app (opt-in)
- [ ] De-identification: blur names, phones and addresses in images and text
- [ ] Label pipeline from user confirmations
- [ ] Train / validation / test split (same doctor never across splits)
- [ ] Fine-tune an open vision-language model (e.g. Qwen2.5-VL 7B) with LoRA/QLoRA
- [ ] Compare with the cloud model on the Phase 2 eval
- [ ] Self-hosted inference (vLLM) and a hybrid router: local first, cloud on low confidence
- [ ] Model versioning and accuracy monitoring

**Exit criteria:** local model's high-confidence accuracy ≥ cloud model's · ≥ 60% of prescriptions
handled locally · lower average cost per prescription

---

## Database outline

| Table | Purpose | Phase |
|---|---|---|
| `drugs` ✅ | Bangladeshi drug catalogue | 1 |
| `profiles` | User: name, phone, language, meal times | 4 |
| `prescriptions` | Uploaded prescriptions (images encrypted in storage) | 4 |
| `medicines` | Confirmed medicines | 4 |
| `schedules` | Dose times | 4 |
| `dose_logs` | Taken / skipped / missed | 5 |
| `caregivers` | Patient ↔ caregiver links | 6 |
| `notifications` | Alerts, SMS and calls sent | 6, 10 |
| `consents` | Consent for data use | 11 |

## Workflow per phase

1. Create a `phase-N-name` branch
2. Implement tasks with tests
3. Small, focused commits
4. Verify the exit criteria
5. Report: what was done, what is pending, issues found
6. Merge into `main` via pull request after approval
