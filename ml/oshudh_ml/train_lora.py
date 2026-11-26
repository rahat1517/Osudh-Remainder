"""LoRA fine-tuning of an open vision-language model on the exported dataset.

    # on a GPU machine (24 GB is enough for a 7B model with 4-bit loading):
    uv sync --extra train
    uv run python -m oshudh_ml.train_lora --data data/v1 --out checkpoints/v1
    uv run python -m oshudh_ml.train_lora --data data/v1 --out checkpoints/v1 --dry-run   # validate only

Serve the merged model with vLLM (OpenAI-compatible API) and set LOCAL_READER_URL / READER_MODE=hybrid
in the backend. Compare against the cloud reader with `backend/eval/run_eval.py --reader local`.
"""

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(frozen=True)
class TrainConfig:
    base_model: str = "Qwen/Qwen2.5-VL-7B-Instruct"
    lora_rank: int = 16
    lora_alpha: int = 32
    lora_dropout: float = 0.05
    learning_rate: float = 1e-4
    epochs: int = 3
    batch_size: int = 1
    grad_accumulation: int = 8
    max_image_pixels: int = 1568 * 1568
    load_in_4bit: bool = True
    seed: int = 7


def parse(argv: list[str] | None = None) -> tuple[argparse.Namespace, TrainConfig]:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--data", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--base-model", default=TrainConfig.base_model)
    p.add_argument("--epochs", type=int, default=TrainConfig.epochs)
    p.add_argument("--lr", type=float, default=TrainConfig.learning_rate)
    p.add_argument("--rank", type=int, default=TrainConfig.lora_rank)
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args(argv)
    return a, TrainConfig(
        base_model=a.base_model,
        epochs=a.epochs,
        learning_rate=a.lr,
        lora_rank=a.rank,
        lora_alpha=2 * a.rank,
    )


def validate_dataset(data: Path) -> dict[str, int]:
    """Checks the files the trainer will read; raises ValueError with a clear message otherwise."""
    counts = {}
    for split in ("train", "validation"):
        path = data / f"{split}.jsonl"
        if not path.exists():
            raise ValueError(f"missing {path}")
        n = 0
        for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            record = json.loads(line)
            image = record["messages"][0]["content"][0]["image"]
            if not (data / image).exists():
                raise ValueError(f"{path.name}:{i}: image {image} not found")
            json.loads(record["messages"][1]["content"][0]["text"])  # target must be valid JSON
            n += 1
        counts[split] = n
    if counts["train"] == 0:
        raise ValueError("training split is empty")
    return counts


def train(args: argparse.Namespace, cfg: TrainConfig) -> None:  # pragma: no cover - needs a GPU
    import torch
    from datasets import load_dataset
    from peft import LoraConfig
    from transformers import AutoModelForVision2Seq, AutoProcessor, BitsAndBytesConfig
    from trl import SFTConfig, SFTTrainer

    quant = (
        BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_compute_dtype=torch.bfloat16)
        if cfg.load_in_4bit
        else None
    )
    model = AutoModelForVision2Seq.from_pretrained(
        cfg.base_model, quantization_config=quant, torch_dtype=torch.bfloat16
    )
    processor = AutoProcessor.from_pretrained(cfg.base_model, max_pixels=cfg.max_image_pixels)
    files = {s: str(args.data / f"{s}.jsonl") for s in ("train", "validation")}
    dataset = load_dataset("json", data_files=files)
    trainer = SFTTrainer(
        model=model,
        processing_class=processor,
        train_dataset=dataset["train"],
        eval_dataset=dataset["validation"],
        peft_config=LoraConfig(
            r=cfg.lora_rank,
            lora_alpha=cfg.lora_alpha,
            lora_dropout=cfg.lora_dropout,
            target_modules="all-linear",
            task_type="CAUSAL_LM",
        ),
        args=SFTConfig(
            output_dir=str(args.out),
            num_train_epochs=cfg.epochs,
            learning_rate=cfg.learning_rate,
            per_device_train_batch_size=cfg.batch_size,
            gradient_accumulation_steps=cfg.grad_accumulation,
            eval_strategy="epoch",
            save_strategy="epoch",
            bf16=True,
            seed=cfg.seed,
            report_to=[],
        ),
    )
    trainer.train()
    trainer.save_model(str(args.out))


def main(argv: list[str] | None = None) -> int:
    args, cfg = parse(argv)
    counts = validate_dataset(args.data)
    print(json.dumps({"config": asdict(cfg), "examples": counts}, indent=2))
    if args.dry_run:
        return 0
    train(args, cfg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
