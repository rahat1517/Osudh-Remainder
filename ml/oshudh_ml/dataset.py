"""Dataset preparation: leakage-free splits and chat-format records for vision-language fine-tuning."""

import hashlib
import json
from collections.abc import Iterable
from dataclasses import dataclass

# Kept in sync with backend/app/prescriptions/prompt.py (the model learns the same task and output)
INSTRUCTION = "Extract the prescribed medicines from this prescription."


@dataclass(frozen=True)
class Example:
    id: str
    image_path: str
    group_key: str
    label: dict


def split_of(group_key: str, seed: str = "oshudh", ratios: tuple[float, float] = (0.8, 0.1)) -> str:
    """Deterministic split by group: every example of a group lands in the same split, so a person's
    prescriptions (often from the same doctor and handwriting) never appear in both train and test."""
    bucket = int(hashlib.sha256(f"{seed}:{group_key}".encode()).hexdigest()[:8], 16) / 0xFFFFFFFF
    if bucket < ratios[0]:
        return "train"
    if bucket < ratios[0] + ratios[1]:
        return "validation"
    return "test"


def to_target(label: dict) -> dict:
    """Training target in the reader's output shape (PrescriptionExtraction), confidence 'high' for
    every field: a human confirmed these values."""
    medicines = []
    for m in label["medicines"]:
        medicines.append(
            {
                "raw_text": "",
                "form": None,
                "name": m["name"],
                "name_confidence": "high",
                "strength": m.get("strength"),
                "strength_confidence": "high",
                "dose_raw": None,
                "dose_pattern": m.get("dose_pattern"),
                "dose_confidence": "high",
                "timing": m.get("timing", "not_specified"),
                "timing_confidence": "high",
                "duration_raw": None,
                "duration_days": m.get("duration_days"),
                "continue_indefinitely": m.get("continue_indefinitely", False),
                "duration_confidence": "high",
                "as_needed": m.get("as_needed", False),
                "other_instructions": None,
            }
        )
    return {"is_prescription": True, "image_quality": "good", "medicines": medicines}


def to_chat_record(example: Example, image_file: str) -> dict:
    return {
        "id": example.id,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "image", "image": image_file},
                    {"type": "text", "text": INSTRUCTION},
                ],
            },
            {
                "role": "assistant",
                "content": [
                    {
                        "type": "text",
                        "text": json.dumps(to_target(example.label), ensure_ascii=False),
                    }
                ],
            },
        ],
    }


def split_examples(examples: Iterable[Example], seed: str = "oshudh") -> dict[str, list[Example]]:
    splits: dict[str, list[Example]] = {"train": [], "validation": [], "test": []}
    for e in examples:
        splits[split_of(e.group_key, seed)].append(e)
    return splits
