# Fine-tuned OCR models

The backend reads prescriptions with PaddleOCR's pretrained models (bundled with
`rapidocr-onnxruntime`). The pretrained recognition model only knows Latin script, so it cannot
read the Bangla doses, timings and durations most prescriptions use (১+০+১, খাবারের আগে, ৭ দিন).

| File | What |
|---|---|
| `rec.onnx` | recognition model fine-tuned for Bangla prescription lines (v1, 2026-11-27) |
| `dict.txt` | its character list: English, then Bangla (must be the one it was trained with) |

The server uses them when these are set (Render → Environment):

```
OCR_REC_MODEL_PATH=/srv/backend/models/rec.onnx
OCR_REC_KEYS_PATH=/srv/backend/models/dict.txt
```

Remove the two variables to go back to the pretrained model.

## v1 (2026-11-27)

- Start: PaddleOCR's English PP-OCRv4 recognition model. The dictionary was extended with Bangla,
  keeping the English weights, so Latin text (names, strengths) reads as before.
- Data: 34,800 synthetic prescription lines (`ml/oshudh_ml/synth_rec.py`) in 10 Bangla fonts
  (Noto Sans/Serif Bengali, Hind Siliguri, Anek Bangla, Baloo Da 2, Galada, Mina, Tiro Bangla). No
  patient data.
- Training: `ml/paddleocr/cpu/train_rec_cpu.sh`, 12 epochs on a 4-core CPU (backbone frozen).
- Lines: 99.5% exactly right on held-out synthetic lines; 95.6% in Atma, a font never trained on.
- Eval gate (`eval/reports/ocr-bangla-v1-2026-11-27.md`, compared with
  `ocr-baseline-2026-11-26.md`), clean / photo:

  | Field | Pretrained | v1 |
  |---|---|---|
  | dose | 34% / 34% | 86% / 90% |
  | timing | 57% / 54% | 89% / 89% |
  | duration | 31% / 31% | 90% / 86% |
  | name, strength | 97%, 96% | unchanged |
  | wrong but marked `high` | 0 | 0 |

  The eval prescriptions are printed in Hind Siliguri, one of the training fonts, so real photos
  will score lower; handwriting is not covered yet.
- Speed and memory: same as the pretrained model (about 1.2 s and 304 MB peak for a 12 MP photo).

## Replacing the model

Only switch after the eval gate passes (`uv run python -m eval.run_eval --reader ocr` with the two
variables pointing at the new files): no field wrong while marked `high`, and accuracy at least the
current model's. Models are not personal data, but are trained on de-identified, reviewed examples
only.
