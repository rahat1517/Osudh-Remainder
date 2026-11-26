"""Assistant conversation loop (Claude Messages API with client-side tools).

Built on the stateless Messages API on purpose: conversations about health data are not stored by a
hosted agent service; the app keeps the short history and sends it with each request.
"""

import logging
from typing import Any

import anthropic

from app.assistant.models import ChatRequest, ChatResponse
from app.assistant.prompt import SYSTEM_PROMPT, context_note
from app.assistant.safety import detect_emergency, emergency_response
from app.assistant.tools import TOOLS, ToolExecutor
from app.drugs.matcher import DrugMatcher

logger = logging.getLogger(__name__)

MAX_TOOL_ROUNDS = 6
FALLBACK_BETA = "server-side-fallback-2026-07-01"

_SORRY = {
    "bn": "দুঃখিত, এখন উত্তর দিতে পারছি না। একটু পরে আবার চেষ্টা করুন।",
    "en": "Sorry, I cannot answer right now. Please try again in a moment.",
}


class AssistantService:
    def __init__(self, client: Any, matcher: DrugMatcher, model: str, effort: str = "low"):
        self._client = client
        self._matcher = matcher
        self._model = model
        self._effort = effort

    def chat(self, request: ChatRequest) -> ChatResponse:
        locale = request.context.locale
        latest = request.messages[-1]
        if latest.role == "user" and (kind := detect_emergency(latest.text)):
            logger.info("emergency detected by rules: %s", kind)
            return ChatResponse(reply=emergency_response(kind, locale), emergency=kind.value)

        executor = ToolExecutor(request.context, self._matcher)
        messages: list[dict] = [{"role": m.role, "content": m.text} for m in request.messages]
        system = [
            {"type": "text", "text": SYSTEM_PROMPT, "cache_control": {"type": "ephemeral"}},
            {"type": "text", "text": context_note(request.context.patient_name, locale)},
        ]

        for _ in range(MAX_TOOL_ROUNDS):
            try:
                response = self._client.beta.messages.create(
                    model=self._model,
                    max_tokens=4000,
                    system=system,
                    tools=TOOLS,
                    messages=messages,
                    output_config={"effort": self._effort},
                    betas=[FALLBACK_BETA],
                    fallbacks="default",
                )
            except anthropic.APIError as e:
                logger.error("assistant API error: %s", e)
                return ChatResponse(reply=_SORRY[locale])

            if response.stop_reason == "refusal":
                return ChatResponse(reply=_SORRY[locale], actions=executor.actions)
            if response.stop_reason != "tool_use":
                text = " ".join(b.text for b in response.content if b.type == "text").strip()
                return ChatResponse(reply=text or _SORRY[locale], actions=executor.actions)

            # Keep the assistant turn unchanged (including thinking blocks), then answer every call
            messages.append({"role": "assistant", "content": response.content})
            results = []
            for block in response.content:
                if block.type == "tool_use":
                    output, is_error = executor.run(block.name, dict(block.input))
                    results.append(
                        {
                            "type": "tool_result",
                            "tool_use_id": block.id,
                            "content": output,
                            "is_error": is_error,
                        }
                    )
            messages.append({"role": "user", "content": results})

        logger.warning("assistant exceeded %d tool rounds", MAX_TOOL_ROUNDS)
        return ChatResponse(reply=_SORRY[locale], actions=executor.actions)
