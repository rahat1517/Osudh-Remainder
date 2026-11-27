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

## Reviewing shared prescriptions

Users who turn on "help improve the reader" in Settings share each confirmed scan. The server
blacks out lines that look personal (name, phone, age, address), stores the image in the private
`training-examples` bucket and adds a `training_examples` row with `review_status = 'pending'`.
Nothing is used for training until a person approves it. In the Supabase dashboard:

1. Table Editor → `training_examples`, filter `review_status = pending`.
2. For each row, open its `image_path` in Storage → `training-examples` and check the image:
   - **Reject** if any personal detail is still readable (a name, phone number, address, face, ID,
     or the doctor's signature or seal), or if it is not a prescription.
   - Otherwise check `label` (what the user confirmed) against the image; **reject** if it is wrong.
3. Set `review_status` to `approved` or `rejected`, `reviewed_by` to your name and `reviewed_at`
   to now.

Only approved rows are exported (`oshudh_ml.export_rec`). Revoking consent in the app deletes the
user's examples that have not been exported yet.

## PaddleOCR fine-tuning (free reader)

Without a Claude key the backend reads prescriptions with PaddleOCR + rules
(`backend/app/prescriptions/ocr_reader.py`). The pretrained models read printed Latin text well
(names 93–97% in the baseline eval) but not Bangla script or messy handwriting. Fine-tuning the
**recognition** model on prescription lines fixes that; detection usually needs no training.

```
synthetic lines (Bangla doses/timings, brand names)  ─┐
approved real examples → OCR → line crops, labelled  ─┼→ train on a free Colab GPU → rec.onnx
reviewer-typed text for skipped crops                 ─┘      → eval gate → backend/models/
```

### 1. Data

```bash
cd ml
uv sync --extra ocr
# a) Synthetic lines: put Bangla and handwriting-style fonts in fonts/ (e.g. Noto Sans Bengali,
#    Hind Siliguri, Galada, Mina from fonts.google.com). Needs Pillow with libraqm for Bangla.
uv run python -m oshudh_ml.synth_rec --fonts fonts/ --out data/synth --count 20000
# b) Real crops from approved, consented, de-identified examples (DATABASE_URL, SUPABASE_URL,
#    SUPABASE_SERVICE_ROLE_KEY)
uv run python -m oshudh_ml.export_rec --out data/rec-v1
```

`export_rec` keeps only lines it can label safely: confident OCR reads that agree with what the user
confirmed, and lines whose medicine name it can correct from the confirmed value. The rest are saved
under `skipped/` and listed in `skipped.tsv`: a reviewer can type the correct text in the third
column and append those rows (`crop<TAB>text`) to `train.txt`. That is how real Bangla handwriting
gets into the data.

Rough guide: the synthetic set alone teaches Bangla digits and common instructions; a few hundred
real prescriptions (a few thousand lines) are what make handwriting work.

### 2. Train (free GPU)

**Easiest: the self-contained notebook.** Open `ml/paddleocr/train_bangla_ocr_colab.ipynb` in
Google Colab (File → Upload notebook), choose Runtime → Change runtime type → T4 GPU, then
Runtime → Run all. It downloads Bangla fonts, generates the synthetic lines, fine-tunes the model,
checks it on unseen lines and downloads `oshudh_ocr_model.zip` (`rec.onnx` + `dict.txt`). It needs
no access to this private repository: the generator and training script are inside it
(rebuild it with `python ml/paddleocr/make_colab_notebook.py` after changing either).

With real data as well, upload `data/` to Colab and run:

```bash
git clone https://github.com/rahat1517/Osudh-Remainder && cd Osudh-Remainder/ml
bash paddleocr/train_rec_colab.sh data/rec-v1 data/synth        # EPOCHS=30 by default
```

It fine-tunes PaddleOCR's English PP-OCRv4 recognition model with a character list that includes
Bangla, then exports `out/rec.onnx` and `out/dict.txt`.

**Without a GPU: `paddleocr/cpu/train_rec_cpu.sh`** (how `backend/models/rec.onnx` v1 was made).
It keeps the pretrained backbone frozen, computes its features once with ONNX Runtime and trains
only the sequence neck and CTC head, so it runs on an ordinary 4-core machine in about 1.5 hours:

```bash
HOLDOUT=data/synth-heldout-font bash paddleocr/cpu/train_rec_cpu.sh data/synth data/rec-v1
```

The GPU route trains the whole model and should cope better with handwriting; the CPU route is
enough for printed Bangla. The CPU script flushes denormal weights to zero (the pretrained English
weights contain many, which made the model 2x slower on CPU); do the same for a Colab model with
`python paddleocr/cpu/flush_denormals.py rec.onnx rec.onnx` (needs `onnx`).

### 3. Eval gate, then switch

```bash
cp out/rec.onnx out/dict.txt ../backend/models/
cd ../backend
OCR_REC_MODEL_PATH=models/rec.onnx OCR_REC_KEYS_PATH=models/dict.txt \
  uv run python -m eval.run_eval --reader ocr
```

Switch only if **no field is wrong while marked `high`** and every field is at least as accurate as
`backend/eval/reports/ocr-baseline-2026-11-26.md`. Then commit the two files and set
`OCR_REC_MODEL_PATH` / `OCR_REC_KEYS_PATH` on the server (`backend/models/README.md`). To roll back,
unset the variables.
