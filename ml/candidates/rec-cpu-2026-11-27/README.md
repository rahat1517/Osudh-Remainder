# Candidate: recognition model fine-tuned on CPU (2026-11-27)

**Not deployed.** It passes "no field wrong while marked high" but not "every field at least as
accurate": photo names 28/30 against 29/30 for the pretrained model (one Calbo D line merged with
its dose). Deploy only if that trade is accepted, or after the full GPU run (Colab notebook).

- Base: PaddleOCR `en_PP-OCRv4_rec`, English output weights kept per character, Bangla added
- Data: 19,200 synthetic lines (`ml/oshudh_ml/synth_rec.py`, 16 fonts, about half Bangla), 1 epoch
  on 4 CPU cores (~1h40), CTC head only, learning rate 3e-4 cosine
- Character list: `dict.txt` (94 English + 38 Bangla and ½)

| Lines (crops) | pretrained (backend now) | this model |
|---|---|---|
| Bangla, validation | 0% exact, 14% chars | 29% exact, 88% chars |
| English, validation | 74% exact, 96% chars | 89% exact, 98% chars |
| Bangla, blurred/compressed | 0% exact, 13% chars | 21% exact, 87% chars |
| English, blurred/compressed | 85% exact, 97% chars | 85% exact, 97% chars |

End to end (`backend/eval/reports/ocr-finetuned-cpu-2026-11-27.md` against
`ocr-baseline-2026-11-27-gallery.md`): dose 31% → 90% (clean), 66% (photo), 55% (gallery);
timing 54–57% → 57–71%; duration 31% → 31–41%; no field wrong while marked high.

To try it:

```bash
cp ml/candidates/rec-cpu-2026-11-27/{rec.onnx,dict.txt} backend/models/
# Render → Environment:
#   OCR_REC_MODEL_PATH=/srv/backend/models/rec.onnx
#   OCR_REC_KEYS_PATH=/srv/backend/models/dict.txt
```
