# Self-hosted model fine-tuning (Phase 11)

Plan:

1. Collect labels from prescriptions users confirmed, with consent and personal data removed.
2. Split 80% train / 10% validation / 10% test, keeping each doctor in a single split.
3. Fine-tune an open vision-language model (e.g. Qwen2.5-VL 7B) with LoRA/QLoRA.
4. Measure on the test set: name, dose, timing and duration accuracy, and calibration of confidence.
5. Hybrid serving: the local model tries first; low-confidence results fall back to the cloud model.

## Rules

- **Never commit real prescriptions or patient data.** `ml/data/` is git-ignored.
- Store model weights (`.safetensors`, `.gguf`) in a private Hugging Face repository.
