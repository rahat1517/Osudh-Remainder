# Prescription reader evaluation

Unit tests use a fake AI. This eval measures real accuracy against the Claude API.
**Run it again whenever the prompt, the model or the verification rules change.**

## Contents

| File | Purpose |
|---|---|
| `cases.json` | 10 fictional prescriptions: the text rendered in the image and the correct answer |
| `generate.py` | Renders two images per case: clean print (`clean`) and a phone-photo look (`photo`) |
| `run_eval.py` | Reads each image through the real API, scores every field, writes a report |

The cases are deliberately hard: Bangla digits, `BD`/`TDS`/`QID`/`HS`, `½`, "চলবে" (continue), SOS,
syrups, misspellings (`Maxpo`, `Alatral`), names without a strength, and lines that must be ignored
(tests such as CBC, general advice).

## Run

```bash
cd backend
uv run python -m eval.generate                    # images only (free), see eval/out/
export ANTHROPIC_API_KEY=...                      # or put it in backend/.env
uv run python -m eval.run_eval --yes --limit 2    # quick check: 4 API calls
uv run python -m eval.run_eval --yes              # full run: 20 API calls
```

Reports are written to `eval/reports/`.

## Phase 2 targets

| Criterion | Target |
|---|---|
| Printed prescriptions, name and dose | ≥ 95% correct |
| Fields marked `high` | ≥ 98% correct |
| Wrong but `high` | as close to zero as possible |

## Limitations

All cases are **fictional and printed**. Measuring accuracy on **handwritten** prescriptions needs
real prescriptions collected with consent and with personal data removed. Those must never be
committed to git.
