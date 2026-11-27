"""Google Gemini as the second reader, for prescriptions the server's own OCR model is unsure of.

Free with a Google AI Studio key (no card), within its rate limits. On the free tier Google may use
what is sent to improve its products, so it is only used for users who agreed (see HybridReader)
and personal lines are blacked out first.
"""

import base64
import copy
import json
import logging
from typing import Any

import httpx2
from pydantic import ValidationError

from app.prescriptions.errors import ReaderError
from app.prescriptions.images import PreparedImage
from app.prescriptions.prompt import SYSTEM_PROMPT, USER_INSTRUCTION
from app.prescriptions.schemas import PrescriptionExtraction

logger = logging.getLogger(__name__)

API = "https://generativelanguage.googleapis.com/v1beta/models"


def inline_refs(schema: dict[str, Any]) -> dict[str, Any]:
    """The JSON schema with every "$ref" replaced by its definition (Gemini's schema support is
    partial; a self-contained schema is understood everywhere)."""
    defs = schema.get("$defs", {})

    def resolve(node: Any) -> Any:
        if isinstance(node, dict):
            if "$ref" in node:
                target = copy.deepcopy(defs[node["$ref"].rsplit("/", 1)[-1]])
                rest = {k: v for k, v in node.items() if k != "$ref"}
                return resolve({**target, **rest})
            return {k: resolve(v) for k, v in node.items() if k != "$defs"}
        if isinstance(node, list):
            return [resolve(v) for v in node]
        return node

    return resolve(schema)


SCHEMA = inline_refs(PrescriptionExtraction.model_json_schema())


class GeminiPrescriptionReader:
    def __init__(self, api_key: str, model: str, client: httpx2.Client | None = None):
        self._url = f"{API}/{model}:generateContent"
        self._headers = {"x-goog-api-key": api_key}
        self._client = client or httpx2.Client(timeout=90)

    def _body(self, image: PreparedImage, with_schema: bool) -> dict[str, Any]:
        config: dict[str, Any] = {"temperature": 0, "responseMimeType": "application/json"}
        instruction = USER_INSTRUCTION
        if with_schema:
            config["responseJsonSchema"] = SCHEMA
        else:  # older models: the schema goes in the prompt
            instruction += "\nReply with JSON matching this schema:\n" + json.dumps(SCHEMA)
        return {
            "systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]},
            "contents": [
                {
                    "role": "user",
                    "parts": [
                        {
                            "inlineData": {
                                "mimeType": image.media_type,
                                "data": base64.b64encode(image.data).decode("ascii"),
                            }
                        },
                        {"text": instruction},
                    ],
                }
            ],
            "generationConfig": config,
        }

    def _post(self, body: dict[str, Any]) -> httpx2.Response:
        try:
            return self._client.post(self._url, json=body, headers=self._headers)
        except httpx2.HTTPError as e:
            raise ReaderError(
                "ai_unavailable", "Cannot reach the AI service", retryable=True
            ) from e

    def read(self, image: PreparedImage) -> PrescriptionExtraction:
        r = self._post(self._body(image, with_schema=True))
        if r.status_code == 400 and "responseJsonSchema" in r.text:
            r = self._post(self._body(image, with_schema=False))
        if r.status_code == 429:
            raise ReaderError(
                "ai_rate_limited", "Too many requests to the AI service", retryable=True
            )
        if r.status_code >= 400:
            # The body never contains the key; it may say why (e.g. an invalid model name)
            logger.error("Gemini API error %s: %s", r.status_code, r.text[:300])
            raise ReaderError(
                "ai_failed", f"AI service error {r.status_code}", retryable=r.status_code >= 500
            )
        try:
            data = r.json()
            if block := data.get("promptFeedback", {}).get("blockReason"):
                logger.warning("Gemini blocked the request: %s", block)
                raise ReaderError("ai_refused", "The AI declined to read this image")
            candidate = data["candidates"][0]
            reason = candidate.get("finishReason")
            if reason == "MAX_TOKENS":
                raise ReaderError(
                    "prescription_too_long", "The prescription is too long to read at once"
                )
            if reason in ("SAFETY", "RECITATION", "PROHIBITED_CONTENT", "BLOCKLIST"):
                raise ReaderError("ai_refused", "The AI declined to read this image")
            text = "".join(
                p.get("text", "")
                for p in candidate["content"]["parts"]
                if not p.get("thought")  # thinking models may return their reasoning too
            )
            return PrescriptionExtraction.model_validate(json.loads(text))
        except ReaderError:
            raise
        except (KeyError, IndexError, ValueError, ValidationError) as e:
            raise ReaderError(
                "ai_failed",
                f"The AI returned no usable result: {type(e).__name__}",
                retryable=True,
            ) from e
