# Self-hosted prescription reader (Phase 11)

Learning from prescriptions users confirmed, with consent, to train a cheaper self-hosted reader that
runs alongside the Claude reader (hybrid).

```
user opts in (Settings) → after confirming a scan, the app shares photo + confirmed values
  → backend: EXIF removed, personal lines redacted, stored privately, queued (review_status = pending)
  → human reviewer approves or rejects each example
  → oshudh_ml.export: approved + consented → JSONL train/validation/test (split by person)
  → oshudh_ml.train_lora: LoRA fine-tune of an open vision-language model (GPU)
  → serve with vLLM → backend READER_MODE=hybrid: local first, Claude when unsure
```

## Privacy rules

- Opt-in only, versioned, revocable in the app; revoking deletes every example not yet exported.
- No free text in labels (only confirmed medicine fields), so labels carry no personal data.
- Images: metadata stripped, personal lines redacted automatically, **and** every example reviewed by a
  person before export. Never commit data: `ml/data/` and all images are git-ignored.
- Group keys are salted hashes; a person's examples stay in one split (no train/test leakage).

## Commands

```bash
cd ml
uv sync                      # data tools only
uv run pytest
uv run python -m oshudh_ml.export --out data/v1
uv sync --extra train        # on the GPU machine
uv run python -m oshudh_ml.train_lora --data data/v1 --out checkpoints/v1
```

## Evaluating against the cloud reader

```bash
cd backend
LOCAL_READER_URL=http://gpu-box:8000 uv run python -m eval.run_eval --yes --reader local
uv run python -m eval.run_eval --yes --reader hybrid
```

Promote the local model only if its high-confidence accuracy is at least the cloud reader's.
