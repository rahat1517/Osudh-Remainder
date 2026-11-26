"""Readers for a self-hosted model and the hybrid routing between it and Claude (Phase 11).

The self-hosted model (e.g. a LoRA fine-tune of an open vision-language model) is served with an
OpenAI-compatible chat API, as vLLM provides, and constrained to the same JSON schema as Claude.
"""

import base64
import json
import logging
from collections import Counter
from typing import Any

import httpx2
from pydantic import ValidationError

from app.drugs.models import Confidence
from app.prescriptions.errors import ReaderError
from app.prescriptions.images import PreparedImage
from app.prescriptions.prompt import SYSTEM_PROMPT, USER_INSTRUCTION
from app.prescriptions.reader import Reader
from app.prescriptions.schemas import ImageQuality, PrescriptionExtraction

logger = logging.getLogger(__name__)


class LocalModelReader:
    def __init__(self, base_url: str, model: str, client: httpx2.Client | None = None):
        self._url = base_url.rstrip("/") + "/v1/chat/completions"
        self._model = model
        self._client = client or httpx2.Client(timeout=60)

    def read(self, image: PreparedImage) -> PrescriptionExtraction:
        data_url = f"data:{image.media_type};base64,{base64.b64encode(image.data).decode('ascii')}"
        body: dict[str, Any] = {
            "model": self._model,
            "temperature": 0,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": [
                        {"type": "image_url", "image_url": {"url": data_url}},
                        {"type": "text", "text": USER_INSTRUCTION},
                    ],
                },
            ],
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": "prescription",
                    "schema": PrescriptionExtraction.model_json_schema(),
                    "strict": True,
                },
            },
        }
        try:
            r = self._client.post(self._url, json=body)
            r.raise_for_status()
            content = r.json()["choices"][0]["message"]["content"]
            return PrescriptionExtraction.model_validate(json.loads(content))
        except (httpx2.HTTPError, KeyError, IndexError, ValueError, ValidationError) as e:
            raise ReaderError("ai_failed", f"Local model failed: {e}", retryable=True) from e


def needs_cloud(extraction: PrescriptionExtraction, max_uncertain_share: float = 0.25) -> bool:
    """When the local model's answer should be double-checked by the cloud model."""
    if not extraction.is_prescription or extraction.image_quality == ImageQuality.POOR:
        return True
    if not extraction.medicines:
        return True
    fields = [
        c
        for m in extraction.medicines
        for c in (
            m.name_confidence,
            m.strength_confidence,
            m.dose_confidence,
            m.timing_confidence,
            m.duration_confidence,
        )
    ]
    if any(
        c == Confidence.LOW
        for m in extraction.medicines
        for c in (m.name_confidence, m.dose_confidence)
    ):
        return True
    uncertain = sum(c != Confidence.HIGH for c in fields)
    return uncertain / len(fields) > max_uncertain_share


class HybridReader:
    """Local model first; the cloud model when the local one fails or is unsure.

    `routes` counts which path served each request (local, cloud_fallback, cloud_after_error), which
    is the main cost and quality signal to monitor.
    """

    def __init__(self, local: Reader, cloud: Reader):
        self._local, self._cloud = local, cloud
        self.routes: Counter[str] = Counter()

    def read(self, image: PreparedImage) -> PrescriptionExtraction:
        try:
            local = self._local.read(image)
        except ReaderError as e:
            logger.warning("local reader failed, using cloud: %s", e.code)
            self.routes["cloud_after_error"] += 1
            return self._cloud.read(image)
        if needs_cloud(local):
            self.routes["cloud_fallback"] += 1
            return self._cloud.read(image)
        self.routes["local"] += 1
        return local
