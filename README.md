# Oshudh Reminder

[![CI](https://github.com/rahat1517/Osudh-Remainder/actions/workflows/ci.yml/badge.svg)](https://github.com/rahat1517/Osudh-Remainder/actions/workflows/ci.yml)

An AI-assisted medicine reminder for Bangladesh. Patients photograph a prescription, the app reads it,
the patient confirms what was read with one tap, and the app reminds them (or their caregivers) to take
each medicine on time, in Bangla.

> **Design principle:** the AI reads and suggests; the patient confirms; deterministic code schedules.
> Nothing the AI produces turns into a reminder without explicit confirmation.

## Features

| | Status |
|---|---|
| Prescription scanning with per-field confidence (printed and handwritten, Bangla and English) | Backend done (Phase 2) |
| Bangladeshi dose notation: `১+০+১`, `½`, `BD`/`TDS`, before/after meals, "চলবে" (continue) | Done |
| Drug catalogue with misspelling-tolerant matching (brand → generic → strength) | Done (dev seed) |
| Deterministic schedule engine, identical on server and phone | Done (Phase 3) |
| Offline full-screen alarms with Bangla voice | Phase 5 |
| Caregiver mode: family members are alerted when a dose is missed | Phase 6 |
| Bangla AI assistant, refill and Ramadan modes, SMS/voice-call escalation | Phases 8-10 |

## Repository layout

```
app/        Flutter mobile app (Android first)
backend/    Python FastAPI service: drug catalogue, prescription reader, schedule engine
database/   Drug catalogue sources and import notes
supabase/   Supabase configuration, migrations and generated seed data
spec/       Language-neutral specifications and shared conformance test vectors
docs/       Product plan, roadmap, specifications
ml/         Planned fine-tuning work for a self-hosted model (Phase 11)
```

## Quick start

```bash
# Backend
cd backend && uv sync && uv run uvicorn app.main:app --reload   # http://localhost:8000/docs

# App
cd app && flutter pub get && flutter run
```

See [backend/README.md](backend/README.md), [app/README.md](app/README.md) and
[CONTRIBUTING.md](CONTRIBUTING.md).

## Technology

| Area | Choice |
|---|---|
| Mobile app | Flutter (Android first) |
| Backend | Python 3.12, FastAPI, uv |
| Database and auth | Supabase (PostgreSQL, row-level security) |
| Prescription reading | Claude vision with structured output; later a fine-tuned self-hosted model (hybrid) |
| Scheduling | Rule-based engine in Python and Dart, checked against a shared conformance suite |
| Alarms | Android exact alarms, fully offline |

## Documentation

- [Product plan](docs/PLAN.md): problem, solution, architecture, risks
- [Roadmap](docs/PHASES.md): twelve phases with tasks and exit criteria
- [Schedule engine specification](docs/SCHEDULE_SPEC.md)
- [Prescription reader evaluation](backend/eval/README.md)

## Safety and privacy

1. Real patient data and prescription images are never committed to this repository.
2. Secrets live only in `.env`, which is git-ignored.
3. The AI never changes a medicine or dose on its own; it can only suggest.
4. No reminder is created until the patient confirms the prescription.
5. Uploaded photos are processed in memory, stripped of metadata, and never stored.

## Disclaimer

This app helps people remember to take their medicines. It is not a substitute for medical advice.
Always follow your doctor's instructions.
