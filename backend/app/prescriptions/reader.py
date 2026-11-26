"""Agent ১: প্রেসক্রিপশন পাঠক। ছবি → structured data (Claude vision + structured output)।"""

import base64
import logging
from typing import Protocol

import anthropic

from app.prescriptions.images import PreparedImage
from app.prescriptions.prompt import SYSTEM_PROMPT, USER_INSTRUCTION
from app.prescriptions.schemas import PrescriptionExtraction

logger = logging.getLogger(__name__)

FALLBACK_BETA = "server-side-fallback-2026-07-01"


class ReaderError(RuntimeError):
    """AI প্রেসক্রিপশন পড়তে পারেনি। `user_message` অ্যাপে দেখানো যায়।"""

    def __init__(self, message: str, user_message: str, retryable: bool = False):
        super().__init__(message)
        self.user_message = user_message
        self.retryable = retryable


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
                # নিরাপত্তা-classifier ভুল করে অনুরোধ ফিরিয়ে দিলে server নিজেই অন্য model-এ চালাবে
                betas=[FALLBACK_BETA],
                fallbacks="default",
            )
        except anthropic.RateLimitError as e:
            raise ReaderError(str(e), "এখন অনেক অনুরোধ আসছে। একটু পরে আবার চেষ্টা করুন।", True) from e
        except anthropic.APIConnectionError as e:
            raise ReaderError(str(e), "AI সেবার সাথে সংযোগ হচ্ছে না। আবার চেষ্টা করুন।", True) from e
        except anthropic.APIStatusError as e:
            retryable = e.status_code >= 500
            logger.error("Claude API error %s: %s", e.status_code, e.message)
            raise ReaderError(str(e), "প্রেসক্রিপশন পড়া যায়নি। আবার চেষ্টা করুন।", retryable) from e

        if response.stop_reason == "refusal":
            raise ReaderError(
                f"refusal: {response.stop_details}",
                "এই ছবিটা পড়া যায়নি। ওষুধের নাম নিজে লিখে যোগ করুন।",
            )
        if response.stop_reason == "max_tokens":
            raise ReaderError("max_tokens reached", "প্রেসক্রিপশনটা অনেক বড়। দুই ভাগে ছবি তুলুন।")
        if response.parsed_output is None:
            raise ReaderError("no parsed output", "প্রেসক্রিপশন পড়া যায়নি। আবার চেষ্টা করুন।", True)

        logger.info(
            "prescription read: request_id=%s model=%s medicines=%d",
            response._request_id,
            response.model,
            len(response.parsed_output.medicines),
        )
        return response.parsed_output
