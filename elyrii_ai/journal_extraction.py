"""Whole-entry, evidence-backed journal extraction. No persistence or mood-tracker writes."""
import asyncio
import json
from pathlib import Path
from typing import Annotated, Literal, Union
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from pydantic import Field, field_validator, model_validator
try:
    from .extraction import StrictModel, Identifier, instant, strict_json, ContextExtractor, ExtractionError, MAX_OUTPUT_BYTES
    from .context_sources import SourceFact, SourceMemory
except ImportError:
    from extraction import StrictModel, Identifier, instant, strict_json, ContextExtractor, ExtractionError, MAX_OUTPUT_BYTES
    from context_sources import SourceFact, SourceMemory

MAX_INPUT_BYTES = 24000
CONTEXT_TOKENS = 32768
MAX_GENERATION_TOKENS = 4096
class JournalSource(StrictModel):
    kind: Literal["journal"]
    id: Identifier
    revision: Annotated[int, Field(gt=0)]
    title: Annotated[str, Field(max_length=24000)]
    body: Annotated[str, Field(max_length=24000)]
    mood: Annotated[str, Field(max_length=1000)] | None
    createdAt: str
    _timestamp = field_validator("createdAt")(instant)

class JournalInput(StrictModel):
    source: JournalSource
    timezone: str | None
    @field_validator("timezone")
    @classmethod
    def zone(cls, value):
        try:
            if value is not None: ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError) as exc:
            raise ValueError("Invalid timezone") from exc
        return value
    @model_validator(mode="after")
    def bounded(self):
        if len(self.model_dump_json().encode()) > MAX_INPUT_BYTES:
            raise ValueError("whole_entry_too_large")
        return self

class JournalProposal(StrictModel):
    candidate: Annotated[Union[SourceFact, SourceMemory], Field(discriminator="kind")]
    field: Literal["title", "body", "mood"]
    evidence: Annotated[str, Field(min_length=1, max_length=4000)]
    certainty: Literal["certain", "uncertain"]
    subject: Literal["author", "other", "unknown"]
    assertion: Literal["affirmed", "negated", "quoted", "hypothetical"]
    category: Literal["stable_fact", "stable_preference", "temporary_emotion", "minor_event", "durable_life_event"]
    temporalExpression: Annotated[str, Field(min_length=1, max_length=4000)] | None
    @model_validator(mode="after")
    def classification(self):
        expected = {"stable_fact": "fact", "stable_preference": "preference", "temporary_emotion": "memory", "minor_event": "memory", "durable_life_event": "memory"}[self.category]
        if self.candidate.kind != expected or (self.candidate.origin == "inferred" and self.certainty != "uncertain"):
            raise ValueError("Invalid classification")
        if isinstance(self.candidate, SourceMemory) and self.candidate.retention != ("long_term" if self.category == "durable_life_event" else "short_term"):
            raise ValueError("Invalid retention")
        return self

class JournalOutput(StrictModel):
    promptVersion: Literal["journal-v1"]
    candidates: Annotated[list[JournalProposal], Field(max_length=8)]

def validate_journal_output(raw, request):
    try:
        if not isinstance(raw, str) or len(raw.encode()) > MAX_OUTPUT_BYTES: raise ValueError("Output limit")
        result = JournalOutput.model_validate(strict_json(raw))
        for p in result.candidates:
            text = getattr(request.source, p.field)
            if text is None or p.evidence not in text: raise ValueError("Unsupported evidence")
            if p.temporalExpression is not None and p.temporalExpression not in p.evidence: raise ValueError("Unsupported date")
            if isinstance(p.candidate, SourceMemory) and p.candidate.eventAt is not None and p.candidate.eventAt not in p.evidence: raise ValueError("Unsupported instant")
            if p.field == "mood" and p.category != "temporary_emotion": raise ValueError("Mood is a dated report")
        return result
    except (ValueError, TypeError, RecursionError) as exc:
        raise ExtractionError("Invalid journal output") from exc

class JournalExtractor(ContextExtractor):
    async def extract(self, request: JournalInput) -> JournalOutput:
        request = JournalInput.model_validate(request.model_dump())
        prompt = (Path(__file__).parent / "prompt/extraction/journal-v1.txt").read_text()
        payload = json.dumps(request.model_dump(), ensure_ascii=False, separators=(",", ":"))
        # UTF-8 bytes conservatively bound byte-fallback tokenizers. Reserve
        # template overhead and output so Ollama cannot silently truncate input.
        if len(prompt.encode()) + len(payload.encode()) + 512 + MAX_GENERATION_TOKENS > CONTEXT_TOKENS:
            raise ExtractionError("Journal exceeds context budget")
        body = {"model": self.model, "messages": [{"role": "system", "content": prompt},
            {"role": "user", "content": payload}],
            "stream": False, "format": JournalOutput.model_json_schema(), "options": {"temperature": 0, "num_predict": MAX_GENERATION_TOKENS, "num_ctx": CONTEXT_TOKENS}}
        try:
            raw = await asyncio.wait_for(self._infer(body), timeout=self.timeout)
            return validate_journal_output(raw, request)
        except Exception as exc:
            raise ExtractionError("Journal extraction failed") from exc
