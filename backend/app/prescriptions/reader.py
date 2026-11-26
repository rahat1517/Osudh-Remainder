"""Agent 1, the prescription reader: image → structured data (Claude vision + structured output)."""

import base64
import logging
from typing import Protocol

import anthropic

from app.prescriptions.errors import ReaderError
from app.prescriptions.images import PreparedImage
from app.prescriptions.prompt import SYSTEM_PROMPT, USER_INSTRUCTION
from app.prescriptions.schemas import PrescriptionExtraction

logger = logging.getLogger(__name__)

FALLBACK_BETA = "server-side-fallback-2026-07-01"


class Reader(Protocol):
    def read(self, image: PreparedImage) -> PrescriptionExtraction: ...


class ClaudePrescriptionReader:
    def __init__(self, client: anthropic.Anthropic, model: str, effort: str = "high"):
        self._client = client
        self._model = model
        self._effort = effort

    def read(self, image: PreparedImage) -> PrescriptionExtraction:
        try:
            response = self._client.beta.messages.parse(
                model=self._model,
                max_tokens=16000,
                system=SYSTEM_PROMPT,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image",
                                "source": {
                                    "type": "base64",
                                    "media_type": image.media_type,
                                    "data": base64.standard_b64encode(image.data).decode("ascii"),
                                },
                            },
                            {"type": "text", "text": USER_INSTRUCTION},
                        ],
                    }
                ],
                output_config={"effort": self._effort},
                output_format=PrescriptionExtraction,
                # If a safety classifier declines by mistake, the API retries on a fallback model
                betas=[FALLBACK_BETA],
                fallbacks="default",
            )
        except anthropic.RateLimitError as e:
            raise ReaderError(
                "ai_rate_limited", "Too many requests to the AI service", retryable=True
            ) from e
        except anthropic.APIConnectionError as e:
            raise ReaderError(
                "ai_unavailable", "Cannot reach the AI service", retryable=True
            ) from e
        except anthropic.APIStatusError as e:
            retryable = e.status_code >= 500
            logger.error("Claude API error %s: %s", e.status_code, e.message)
            raise ReaderError(
                "ai_failed", f"AI service error {e.status_code}", retryable=retryable
            ) from e

        if response.stop_reason == "refusal":
            logger.warning("prescription read refused: %s", response.stop_details)
            raise ReaderError("ai_refused", "The AI declined to read this image")
        if response.stop_reason == "max_tokens":
            raise ReaderError(
                "prescription_too_long", "The prescription is too long to read at once"
            )
        if response.parsed_output is None:
            raise ReaderError("ai_failed", "The AI returned no structured output", retryable=True)

        logger.info(
            "prescription read: request_id=%s model=%s medicines=%d",
            response._request_id,
            response.model,
            len(response.parsed_output.medicines),
        )
        return response.parsed_output
