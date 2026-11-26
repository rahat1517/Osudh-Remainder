# Fine-tuned OCR models

The backend reads prescriptions with PaddleOCR's pretrained models (bundled with
`rapidocr-onnxruntime`). A recognition model fine-tuned on prescription lines (see
`ml/README.md`, "PaddleOCR fine-tuning") goes here:

| File | What |
|---|---|
| `rec.onnx` | recognition model from `ml/paddleocr/train_rec_colab.sh` |
| `dict.txt` | its character list (must be the one it was trained with) |

Then set, on the server (Render → Environment):

```
OCR_REC_MODEL_PATH=/srv/backend/models/rec.onnx
OCR_REC_KEYS_PATH=/srv/backend/models/dict.txt
```

Only switch after the eval gate passes (`uv run python -m eval.run_eval --reader ocr` with those
variables set): no field wrong while marked `high`, and accuracy at least the pretrained baseline in
`eval/reports/ocr-baseline-2026-11-26.md`. Models are not personal data, but are trained on
de-identified, reviewed examples only.
