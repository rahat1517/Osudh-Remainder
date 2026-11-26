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
| **4** | App: onboarding, scan and confirm | app | 2-3 weeks | ⬜ |
| **5** | Offline alarm engine and Bangla voice | app | 2 weeks | ⬜ |
| **6** | Caregiver mode | app, backend | 1-2 weeks | ⬜ |
| **7** | Testing, pilot and Play Store | all | 2-3 weeks | ⬜ |
| | **MVP launch** | | **~3-4 months** | |
| **8** | Bangla AI assistant | backend, app | 2 weeks | ⬜ |
| **9** | Learning, refills and Ramadan mode | backend, app | 2 weeks | ⬜ |
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

## Phase 4: App onboarding, scan and confirm ⬜

**Goal:** a user can install the app and confirm a prescription.
**Depends on:** Phases 2, 3

- [ ] Schema: `profiles`, `prescriptions`, `medicines`, `schedules` with row-level security
- [ ] Phone login (Supabase OTP, automatic SMS code reading on Android)
- [ ] Onboarding: welcome → login → permissions → first prescription
- [ ] Camera or gallery capture, crop and quality hints
- [ ] **Confirm screen:** high (filled), medium (highlighted), low (empty) → edit → Confirm
- [ ] Localized texts for every backend error and notice code
- [ ] Medicine-name autocomplete
- [ ] Manual entry without a prescription
- [ ] Home screen: today's medicines and next dose
- [ ] Medicine list: edit and stop
- [ ] Large text, large buttons, simple Bangla

**Exit criteria:**
- A new user confirms a first prescription within 3 minutes
- No schedule exists without confirmation
- Users cannot see each other's data (RLS tests)

---

## Phase 5: Offline alarm engine and Bangla voice ⬜

**Goal:** alarms fire on time without internet, even with the phone locked.
**Depends on:** Phase 4

- [ ] Local schedule storage (SQLite / Drift), generated by the Dart schedule engine
- [ ] Exact alarms (`setExactAndAllowWhileIdle`, `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`)
- [ ] Full-screen alarm over the lock screen: name, picture, amount
- [ ] Buttons: Taken / Snooze 10 min / Skip; up to 3 snoozes
- [ ] Bangla text-to-speech
- [ ] Re-register alarms on boot and on time or time-zone change
- [ ] Brand-specific battery and autostart guidance
- [ ] Dose log stored locally, synced when online
- [ ] Tested on real devices (Xiaomi, Realme and at least one more brand)

**Exit criteria:** alarm fires on time in airplane mode with the phone locked after 8 hours ·
survives restart · tested on at least 3 brands

---

## Phase 6: Caregiver mode ⬜

**Goal:** family members see the schedule and are alerted about missed doses.
**Depends on:** Phase 5

- [ ] `caregivers` schema with permission levels (view / edit)
- [ ] Invitation by code or link, with the patient's consent
- [ ] Caregiver dashboard: taken and missed doses today
- [ ] Caregiver can add prescriptions on the patient's behalf
- [ ] Missed-dose push notification (FCM) after 30 minutes without "Taken"
- [ ] Server-side missed-dose detection job
- [ ] Revoking access

**Exit criteria:** caregiver notified within 35 minutes of a missed dose · no access without consent

---

## Phase 7: Testing, pilot and Play Store ⬜

**Goal:** validate with real users and release safely.
**Depends on:** Phase 6

- [ ] End-to-end tests of the full flow
- [ ] Security review: RLS, API auth, rate limits, key management
- [ ] Privacy policy and terms (Bangla and English); medical disclaimer
- [ ] In-app account and data deletion
- [ ] Crash reporting and privacy-preserving analytics
- [ ] **Pilot:** 20-50 users (older patients and caregivers) for 2-3 weeks
- [ ] Fixes from pilot feedback
- [ ] Play Store: health app declaration, exact-alarm justification, Bangla listing
- [ ] Internal → closed testing → production

**Exit criteria:** alarm reliability ≥ 99% in the pilot · crash-free sessions ≥ 99% · Play Store
review passed

---

## Phase 8: Bangla AI assistant ⬜

- [ ] Chat in Bangla, voice input (speech-to-text) and voice replies
- [ ] Tools: show today's schedule, stop a medicine (with confirmation), change a time (with confirmation)
- [ ] Safety: dose questions ("I missed one, should I take two?") are referred to a doctor or pharmacist
- [ ] Emergency symptoms (chest pain, breathing difficulty) → call 999 / nearest hospital
- [ ] Conversation eval: 100 questions with safe-answer criteria

**Exit criteria:** 100% on the safety eval · ≥ 90% correct on common questions

---

## Phase 9: Learning, refills and Ramadan mode ⬜

- [ ] Learn actual dose times; propose a change after 3+ consistent days
- [ ] Track pill counts; refill reminder 3 days before running out
- [ ] Ramadan mode: sehri and iftar times by district
- [ ] Weekly adherence report and PDF for the doctor
- [ ] Duplicate-therapy warning (same generic on two prescriptions)

**Exit criteria:** no suggestion takes effect without the user's "Yes" · Ramadan mode tested for
Dhaka, Chattogram and Sylhet

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
