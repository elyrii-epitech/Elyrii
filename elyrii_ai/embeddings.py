"""Bounded, digest-checked Ollama embedding adapter. Memories remain readable text."""
import asyncio
import math
from typing import Annotated, Literal

import httpx
from pydantic import Field, model_validator

try:
    from .extraction import StrictModel, Identifier, strict_json
except ImportError:
    from extraction import StrictModel, Identifier, strict_json


class EmbeddingModel(StrictModel):
    id: Annotated[str, Field(min_length=1, max_length=200)]
    providerModel: Literal["embeddinggemma:300m"]
    digest: Annotated[str, Field(pattern=r"^[0-9a-f]{64}$")]
    dimensions: Literal[768]
    metric: Literal["cosine"]
    preprocessing: Literal["raw-v1"]

    @model_validator(mode="after")
    def version_identity(self):
        if self.id != f"embeddinggemma-300m@sha256:{self.digest}:raw-v1:768":
            raise ValueError("Version does not match the model artifact and encoding policy")
        return self


def model_spec(digest):
    return EmbeddingModel(id=f"embeddinggemma-300m@sha256:{digest}:raw-v1:768",
        providerModel="embeddinggemma:300m", digest=digest, dimensions=768, metric="cosine", preprocessing="raw-v1")


class EmbeddingJob(StrictModel):
    version: Literal[1]
    jobId: Identifier
    memoryId: Identifier
    userId: Identifier
    model: Annotated[str, Field(min_length=1, max_length=200)]
    contentRevision: Annotated[int, Field(ge=1)]
    attempt: Annotated[int, Field(ge=1, le=5)]
    spec: EmbeddingModel
    content: Annotated[str, Field(min_length=1, max_length=10000)]

    @model_validator(mode="after")
    def version_matches(self):
        if self.model != self.spec.id:
            raise ValueError("Model metadata mismatch")
        return self


class ModelMismatch(ValueError):
    pass


class InvalidEmbeddingInput(ValueError):
    pass


class OllamaEmbeddingAdapter:
    def __init__(self, client: httpx.AsyncClient, spec: EmbeddingModel, timeout=30.0):
        if not 0 < timeout <= 60:
            raise ValueError("Timeout must be in (0, 60]")
        self.client, self.spec, self.timeout = client, spec, timeout

    async def _json(self, method, path, body=None):
        async with self.client.stream(method, path, json=body, timeout=self.timeout) as response:
            if response.status_code in (400, 413) and path == "/api/embed":
                raise InvalidEmbeddingInput("Input exceeds provider limits or is unsupported")
            response.raise_for_status()
            data = bytearray()
            async for chunk in response.aiter_bytes():
                if len(data) + len(chunk) > 256000:
                    raise ValueError("Oversized provider response")
                data.extend(chunk)
            return strict_json(data)

    async def _verify_digest(self):
        listing = await self._json("GET", "/api/tags")
        if not isinstance(listing, dict) or not isinstance(listing.get("models"), list):
            raise ModelMismatch("No model manifest")
        matches = [m for m in listing["models"] if isinstance(m, dict) and m.get("name") == self.spec.providerModel]
        if len(matches) != 1 or str(matches[0].get("digest", "")).removeprefix("sha256:") != self.spec.digest:
            raise ModelMismatch("Serving model does not match the configured artifact")

    async def embed(self, content: str):
        if not isinstance(content, str) or not content.strip() or len(content) > 10000 or len(content.encode("utf-8")) > 40000:
            raise InvalidEmbeddingInput("Invalid readable memory content")
        return await asyncio.wait_for(self._embed(content), timeout=self.timeout)

    async def _embed(self, content):
        await self._verify_digest()
        result = await self._json("POST", "/api/embed", {"model": self.spec.providerModel, "input": content,
            "truncate": False, "dimensions": self.spec.dimensions, "options": {"num_ctx": 2048}})
        if not isinstance(result, dict) or result.get("model") != self.spec.providerModel:
            raise ModelMismatch("Unexpected provider model")
        batch = result.get("embeddings")
        if not isinstance(batch, list) or len(batch) != 1 or not isinstance(batch[0], list) or len(batch[0]) != self.spec.dimensions:
            raise ValueError("Unexpected vector dimensions")
        vector = batch[0]
        if any(type(v) not in (float, int) or not math.isfinite(v) for v in vector):
            raise ValueError("Non-finite or nonnumeric vector")
        norm = math.hypot(*vector)
        if not math.isfinite(norm) or norm == 0:
            raise ValueError("Invalid zero or overflowing vector")
        # Make cosine preprocessing explicit and reproducible, rather than relying
        # on provider defaults. No dimensional truncation or text truncation.
        normalized = [value / norm for value in vector]
        await self._verify_digest()
        return normalized
