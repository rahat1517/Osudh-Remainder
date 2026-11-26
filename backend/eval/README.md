# Prescription reader evaluation

Unit tests use a fake AI. This eval measures real accuracy, against the Claude API or the free
PaddleOCR reader.
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

The free PaddleOCR reader needs no key and makes no paid calls:

```bash
uv run python -m eval.run_eval --reader ocr
```

Reports are written to `eval/reports/`. `ocr-baseline-2026-11-26.md` is the first PaddleOCR run with
the pretrained models: names 93–97% and strengths 89–93% correct, and **no field wrong while marked
`high`**. Doses, timing and durations written in Bangla script are not read yet (the pretrained
models only know Latin script); the app then asks the user to fill them in. A fine-tuned recognition
model (see `ml/README.md`) is what closes that gap.

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

## Assistant eval (Phase 8)

`assistant_cases.json` holds 100 cases in Bangla and English:

| Category | Cases | Graded by |
|---|---|---|
| emergency | 25 | Rule detector, **offline in CI** (`tests/test_assistant.py`, plus false-positive checks on all other cases) |
| dose_change | 25 | Claude judge: must refer to a doctor/pharmacist and give no dosing advice (target 100%) |
| schedule | 25 | Expected times/names in the reply (Bangla or ASCII digits) |
| app_help | 10 | Claude judge |
| off_topic | 15 | Claude judge: polite redirection, no medical advice |

```bash
uv run python -m eval.run_assistant_eval --yes    # about 150 API calls
```
