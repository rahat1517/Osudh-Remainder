import json
from collections import Counter

import pytest

from oshudh_ml.dataset import Example, split_examples, split_of, to_chat_record, to_target
from oshudh_ml.export import export
from oshudh_ml.train_lora import main as train_main
from oshudh_ml.train_lora import validate_dataset

LABEL = {
    "medicines": [
        {
            "name": "Seclo",
            "strength": "20 mg",
            "dose_pattern": "1+0+1",
            "timing": "before_meal",
            "duration_days": 30,
        }
    ]
}


def examples(n_groups=200, per_group=3):
    return [
        Example(f"g{g}-{i}", f"training/g{g}-{i}.jpg", f"group{g}", LABEL)
        for g in range(n_groups)
        for i in range(per_group)
    ]


def test_splits_never_share_a_group():
    splits = split_examples(examples())
    groups = {s: {e.group_key for e in items} for s, items in splits.items()}
    assert not groups["train"] & groups["test"]
    assert not groups["train"] & groups["validation"]
    assert not groups["validation"] & groups["test"]


def test_split_ratios_are_roughly_80_10_10_and_deterministic():
    counts = Counter(split_of(f"group{g}") for g in range(5000))
    assert 0.77 < counts["train"] / 5000 < 0.83
    assert 0.08 < counts["validation"] / 5000 < 0.12
    assert split_of("abc") == split_of("abc")
    assert split_of("abc", seed="other") in {"train", "validation", "test"}


def test_target_matches_reader_schema_shape():
    target = to_target(LABEL)
    m = target["medicines"][0]
    assert m["name"] == "Seclo" and m["dose_pattern"] == "1+0+1"
    assert m["name_confidence"] == "high" and m["raw_text"] == ""
    assert set(m) == {
        "raw_text",
        "form",
        "name",
        "name_confidence",
        "strength",
        "strength_confidence",
        "dose_raw",
        "dose_pattern",
        "dose_confidence",
        "timing",
        "timing_confidence",
        "duration_raw",
        "duration_days",
        "continue_indefinitely",
        "duration_confidence",
        "as_needed",
        "other_instructions",
    }


def test_chat_record():
    r = to_chat_record(Example("1", "p", "g", LABEL), "images/1.jpg")
    assert r["messages"][0]["content"][0] == {"type": "image", "image": "images/1.jpg"}
    assert json.loads(r["messages"][1]["content"][0]["text"])["medicines"][0]["name"] == "Seclo"


def test_export_writes_a_valid_dataset(tmp_path):
    counts = export(examples(50, 2), tmp_path, download=lambda path: b"\xff\xd8 fake jpeg")
    assert sum(counts.values()) == 100
    assert validate_dataset(tmp_path)["train"] == counts["train"]
    assert json.loads((tmp_path / "manifest.json").read_text())["counts"] == counts


def test_trainer_dry_run_validates_and_stops(tmp_path, capsys):
    export(examples(50, 2), tmp_path / "data", download=lambda p: b"x")
    assert (
        train_main(["--data", str(tmp_path / "data"), "--out", str(tmp_path / "ckpt"), "--dry-run"])
        == 0
    )
    assert '"base_model": "Qwen/Qwen2.5-VL-7B-Instruct"' in capsys.readouterr().out


def test_validation_catches_missing_images(tmp_path):
    export(examples(20, 1), tmp_path, download=lambda p: b"x")
    first = next((tmp_path / "images").iterdir())
    first.unlink()
    with pytest.raises(ValueError, match="not found"):
        validate_dataset(tmp_path)
