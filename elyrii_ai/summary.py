"""Rolling summaries with exact tokenizer budgets and contiguous coverage."""
import asyncio
import json
from pathlib import Path
from typing import Annotated, Literal

import httpx
from pydantic import Field, field_validator, model_validator

try:
    from .extraction import StrictModel, Identifier, instant, strict_json
except ImportError:
    from extraction import StrictModel, Identifier, instant, strict_json


class SummaryPolicy(StrictModel):
    messageThreshold: Annotated[int, Field(ge=1, le=64)]
    tokenThreshold: Annotated[int, Field(ge=1, le=32000)]
    maxInputTokens: Annotated[int, Field(ge=256, le=32000)]
    maxOutputTokens: Annotated[int, Field(ge=16, le=2048)]


class SummaryMessage(StrictModel):
    id: Identifier
    role: Literal["user", "assistant", "system"]
    content: Annotated[str, Field(min_length=1, max_length=100000)]
    messageAt: str

    @field_validator("messageAt")
    @classmethod
    def timestamp(cls, value):
        return instant(value)


class SummaryJob(StrictModel):
    version: Literal[1]
    jobId: Identifier
    userId: Identifier
    conversationId: Annotated[str, Field(min_length=1, max_length=200)]
    revision: Annotated[int, Field(ge=0)]
    attempt: Annotated[int, Field(ge=1, le=5)]
    model: Annotated[str, Field(min_length=1, max_length=200)]
    policy: SummaryPolicy
    timezone: Annotated[str, Field(min_length=1, max_length=100)]
    priorSummary: Annotated[str, Field(max_length=20000)] | None
    priorThroughMessageId: Identifier | None
    messages: Annotated[list[SummaryMessage], Field(min_length=1, max_length=64)]

    @model_validator(mode="after")
    def unique_messages(self):
        ids = [m.id for m in self.messages]
        if len(set(ids)) != len(ids) or self.priorThroughMessageId in ids:
            raise ValueError("Duplicate coverage")
        if (self.priorSummary is None) != (self.priorThroughMessageId is None):
            raise ValueError("Prior summary and boundary must be paired")
        from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
        try:
            ZoneInfo(self.timezone)
        except (ZoneInfoNotFoundError, ValueError) as exc:
            raise ValueError("Expected an IANA timezone") from exc
        return self


class SummaryInputTooLarge(ValueError):
    pass


class RollingSummarizer:
    """Tokenizer must be the selected generation model's tokenizer.json.

    No heuristic character-to-token ratios and no truncation of source messages.
    A tokenizer is injected for deterministic tests; production loads it locally.
    """
    def __init__(self, client: httpx.AsyncClient, model: str, tokenizer, timeout=30.0):
        if not model.strip() or not 0 < timeout <= 60:
            raise ValueError("A model and timeout in (0, 60] seconds are required")
        self.client = client
        self.model = model
        self.tokenizer = tokenizer
        self.tokenizer.no_truncation()
        self.tokenizer.no_padding()
        self.timeout = timeout
        self.prompt = (Path(__file__).parent / "prompt" / "summary" / "v1.txt").read_text()

    def tokens(self, text: str, special=False) -> int:
        return len(self.tokenizer.encode(text, add_special_tokens=special).ids)

    def input_prompt(self, job, messages):
        return self.prompt + "\n\n" + json.dumps({"priorSummary": job.priorSummary, "timezone": job.timezone,
            "outputTokenBudget": job.policy.maxOutputTokens, "messages": [m.model_dump() for m in messages]}, ensure_ascii=False)

    async def summarize(self, job: SummaryJob):
        if job.model != self.model:
            raise ValueError("Configured tokenizer/model does not match job model")
        policy = job.policy
        message_tokens = sum(self.tokens(m.content) for m in job.messages)
        if len(job.messages) < policy.messageThreshold and message_tokens < policy.tokenThreshold:
            return {"status": "skipped"}
        prefix = []
        for message in job.messages:
            if self.tokens(self.input_prompt(job, [*prefix, message]), special=True) > policy.maxInputTokens:
                break
            prefix.append(message)
        if not prefix:
            raise SummaryInputTooLarge("Oldest source and prior summary exceed the input budget")
        body = {"model": self.model, "prompt": self.input_prompt(job, prefix), "raw": True, "stream": False,
            "options": {"temperature": 0, "num_predict": policy.maxOutputTokens,
                        "num_ctx": policy.maxInputTokens + policy.maxOutputTokens + 32}}
        raw = await asyncio.wait_for(self._infer(body), timeout=self.timeout)
        summary = raw.strip()
        output_tokens = self.tokens(summary)
        if not summary or len(summary) > 20000 or not 0 < output_tokens <= policy.maxOutputTokens:
            raise ValueError("Summary exceeds the selected tokenizer's output budget")
        return {"status": "success", "summary": summary, "throughMessageId": prefix[-1].id, "outputTokens": output_tokens}

    async def _infer(self, body):
        async with self.client.stream("POST", "/api/generate", json=body, timeout=self.timeout) as response:
            response.raise_for_status()
            data = bytearray()
            async for chunk in response.aiter_bytes():
                if len(data) + len(chunk) > 100000:
                    raise ValueError("Oversized summary response")
                data.extend(chunk)
            result = strict_json(data)
            if not isinstance(result, dict) or result.get("done") is not True or result.get("done_reason") == "length":
                raise ValueError("Incomplete summary generation")
            if not isinstance(result.get("response"), str):
                raise ValueError("Invalid summary output")
            return result["response"]
