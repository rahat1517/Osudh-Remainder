# Backend

Python 3.12 + FastAPI, managed with [uv](https://docs.astral.sh/uv/).

## Run

```bash
cd backend
cp ../.env.example .env      # first time; fill in real values
uv sync
uv run uvicorn app.main:app --reload
```

Open http://localhost:8000/health and the interactive API docs at http://localhost:8000/docs.

## Test and lint

```bash
uv run pytest
uv run ruff check .
uv run ruff format --check .
```

## API

| Endpoint | Purpose |
|---|---|
| `GET /health` | Liveness check |
| `GET /drugs/search?q=maxp` | Autocomplete by brand or generic name; tolerates misspellings |
| `POST /drugs/match` `{"text": "Tab. Sec1o 20mg"}` | One prescription line → closest drug + confidence |
| `GET /drugs/{id}` | One drug |
| `POST /prescriptions/extract` (multipart `image`) | Prescription photo → medicines with per-field confidence. Needs `ANTHROPIC_API_KEY`, otherwise 503 |
| `POST /schedules/generate` | Confirmed medicines → dose times and grouped reminders ([spec](../docs/SCHEDULE_SPEC.md)) |

### Confidence levels

| Value | Meaning | App behaviour |
|---|---|---|
| `high` | Near-exact, unambiguous, consistent with the catalogue | Filled in |
| `medium` | Probable but not certain (typo, strength not confirmed) | Highlighted, user asked to check |
| `low` | Not found or unreadable | Left for the user |

### Errors

Every error has the shape `{"detail": {"code": "...", "message": "..."}}`. The `code` is stable and
documented; clients localize it. The `message` is English, for developers.

| Code | Status | Endpoint |
|---|---|---|
| `image_missing`, `image_too_large`, `image_unreadable`, `image_format_unsupported`, `image_too_small` | 422 | extract |
| `not_a_prescription` | 422 | extract |
| `ai_not_configured`, `ai_rate_limited`, `ai_unavailable` | 503 (retry) | extract |
| `ai_refused`, `ai_failed`, `prescription_too_long` | 502 | extract |
| `drug_not_found` | 404 | drugs |
| `invalid_dose_pattern`, `invalid_interval`, `invalid_duration`, `invalid_weekdays`, `invalid_meal_times`, `invalid_timezone`, `missing_dose`, `conflicting_dose` | 422 | schedules (with `medicine_id`) |

Fields and warnings in a prescription result may carry a **notice** `{code, message, params}`:
`name_unreadable`, `name_not_in_catalog`, `name_corrected {written, matched}`,
`strength_not_in_catalog {written}`, `strength_suggested {suggested}`, `dose_unreadable {written}`,
`dose_missing`, `dose_as_needed`, `timing_not_specified`, `duration_unclear`,
`duration_out_of_range {days}`, `duration_missing`; warnings: `image_poor_quality`,
`no_medicines_found`, `review_highlighted_fields`.

## How a prescription is read

```
image → prepare (resize, strip EXIF/GPS) → Agent 1: Claude (read) → Agent 2: rules (verify) → result
```

- **Agent 1** (`app/prescriptions/reader.py`): Claude vision with structured output. Instructions in
  `prompt.py`.
- **Agent 2** (`app/prescriptions/verifier.py`): rules, not AI. Matches names against the catalogue,
  validates doses and durations. **The final confidence never exceeds the AI's own.**
- Images are never stored. The schema has no fields for patient identity.
- Accuracy: [eval/README.md](eval/README.md)

## Layout

```
backend/
├── app/
│   ├── main.py          FastAPI app and lifespan
│   ├── config.py        Settings (.env)
│   ├── api/             Endpoints and error responses
│   ├── drugs/           Catalogue: normalisation, matcher, importer
│   ├── prescriptions/   Reader (Agent 1), verifier (Agent 2), image preparation
│   └── schedule/        Rule-based schedule engine
├── eval/                Prescription-reader accuracy against the real API
├── scripts/             Tooling (schedule parity export)
└── tests/               Unit, property-based and conformance tests
```

## Planned

- Agent 4: Bangla assistant (Phase 8)
- Agent 5: learning and monitoring (Phase 9)

Never put API keys in code; use `.env`.
