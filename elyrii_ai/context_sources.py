"""Version 2 source storage DTOs. Journal inference/consumption is deliberately not enabled."""
from typing import Annotated, Literal, Union
from pydantic import BaseModel, ConfigDict, Field, JsonValue, field_validator
try:
    from .extraction import Identifier, instant
except ImportError:
    from extraction import Identifier, instant


class StrictSourceModel(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)


class SourceReference(StrictSourceModel):
    kind: Literal["chat", "journal"]
    id: Identifier
    revision: Annotated[int, Field(gt=0)]


class SourceFact(StrictSourceModel):
    kind: Literal["fact", "preference"]
    key: Annotated[str, Field(min_length=1, max_length=200, pattern=r"\S")]
    value: JsonValue
    origin: Literal["explicit", "inferred"]

    @field_validator("value")
    @classmethod
    def not_null(cls, value):
        if value is None: raise ValueError("Fact value cannot be null")
        return value


class SourceMemory(StrictSourceModel):
    kind: Literal["memory"]
    content: Annotated[str, Field(min_length=1, max_length=10000, pattern=r"\S")]
    origin: Literal["explicit", "inferred"]
    retention: Literal["short_term", "long_term"]
    eventAt: str | None

    @field_validator("eventAt")
    @classmethod
    def timestamp(cls, value):
        return instant(value) if value is not None else None


class SourceResult(StrictSourceModel):
    version: Literal[2]
    eventId: Identifier
    userId: Identifier
    generation: Annotated[int, Field(ge=0)]
    source: SourceReference
    candidates: Annotated[list[Annotated[Union[SourceFact, SourceMemory], Field(discriminator="kind")]], Field(max_length=8)]
