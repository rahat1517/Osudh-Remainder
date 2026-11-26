"""Collects consented training examples: redacted image + confirmed values, queued for review."""

import hashlib
import json
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from pydantic import BaseModel, Field

from app.prescriptions.images import prepare_image
from app.prescriptions.schemas import Timing
from app.training.deid import LineDetector, redact


class TrainingError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code, self.message = code, message


class ConfirmedMedicine(BaseModel):
    """What the user confirmed: the target the model learns. No free text, so no personal data."""

    name: str = Field(max_length=100)
    strength: str | None = Field(default=None, max_length=50)
    dose_pattern: str | None = Field(default=None, max_length=40)
    timing: Timing = Timing.NOT_SPECIFIED
    duration_days: int | None = Field(default=None, ge=1, le=365)
    continue_indefinitely: bool = False
    as_needed: bool = False


class TrainingLabel(BaseModel):
    medicines: list[ConfirmedMedicine] = Field(min_length=1, max_length=30)


class ExampleStore(Protocol):
    def put(self, path: str, data: bytes) -> None: ...


class TrainingRepository(Protocol):
    def consent_version(self, user_id: str) -> int | None: ...

    def insert_example(self, **fields) -> str: ...


class LocalDirStore:
    def __init__(self, root: Path):
        self._root = root

    def put(self, path: str, data: bytes) -> None:
        target = self._root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)


@dataclass
class SubmitResult:
    example_id: str
    redacted_lines: int


def group_key(user_id: str, pepper: str) -> str:
    """Stable, non-reversible key so one person's prescriptions stay in a single dataset split."""
    return hashlib.sha256(f"{pepper}:{user_id}".encode()).hexdigest()[:16]


class TrainingService:
    def __init__(
        self, repo: TrainingRepository, store: ExampleStore, detector: LineDetector, pepper: str
    ):
        self._repo, self._store, self._detector, self._pepper = repo, store, detector, pepper

    def submit(self, user_id: str, raw_image: bytes, label: TrainingLabel) -> SubmitResult:
        version = self._repo.consent_version(user_id)
        if version is None:
            raise TrainingError(
                "training_not_consented", "The user has not agreed to share prescriptions"
            )
        image = prepare_image(raw_image)  # strips EXIF/GPS
        redacted, count = redact(image.data, self._detector.detect(image.data))
        path = f"training/{uuid.uuid4().hex}.jpg"
        self._store.put(path, redacted)
        example_id = self._repo.insert_example(
            user_id=user_id,
            consent_version=version,
            image_path=path,
            label=json.loads(label.model_dump_json()),
            group_key=group_key(user_id, self._pepper),
            redacted_lines=count,
        )
        return SubmitResult(example_id, count)
