"""Separate Kafka worker; chat response generation never waits for it."""

import asyncio
import logging
import os
from typing import Annotated, Literal

import httpx
from pydantic import Field, ValidationError, model_validator

try:  # Package import for tests; direct script execution in the bridge image.
    from .extraction import ContextExtractor, ExtractionRequest, StrictModel, Identifier, strict_json
except ImportError:
    from extraction import ContextExtractor, ExtractionRequest, StrictModel, Identifier, strict_json

JOBS_TOPIC = "elyrii.context.extraction.jobs.v1"
RESULTS_TOPIC = "elyrii.context.extraction.results.v1"
logger = logging.getLogger(__name__)


class ExtractionJob(StrictModel):
    version: Literal[1]
    jobId: Identifier
    requestId: Identifier
    userId: Identifier
    conversationId: Annotated[str, Field(min_length=1, max_length=200)]
    sourceMessageId: Identifier
    extractorVersion: Literal["v1"]
    attempt: Annotated[int, Field(ge=1, le=5)]
    input: ExtractionRequest

    @model_validator(mode="after")
    def source_matches(self):
        if self.sourceMessageId != self.input.source.id:
            raise ValueError("Source ID mismatch")
        return self


async def process_job(raw: bytes, extractor, publish):
    """Publish before committing the input offset. Errors contain no private data."""
    if len(raw) > 65536:
        return
    try:
        job = ExtractionJob.model_validate(strict_json(raw))
    except (ValueError, TypeError, RecursionError):
        # An untrusted envelope cannot safely identify a job. The outbox timeout
        # bounds retries and records exhaustion even when no result can be sent.
        return
    result = job.model_dump(exclude={"input"})
    try:
        output = await extractor.extract(job.input)
        result.update(status="success", output=output.model_dump())
    except ValidationError:
        result.update(status="failure", error="invalid_input")
    except Exception:
        result.update(status="failure", error="inference_failed")
    # A publish failure must escape: never acknowledge an unpublished result.
    await publish(job.userId, result)


async def run_worker():
    # Keep Kafka optional for deterministic unit tests and extractor-only callers.
    from aiokafka import AIOKafkaConsumer, AIOKafkaProducer
    import json

    broker = os.getenv("KAFKA_BROKER", "localhost:9092")
    consumer = AIOKafkaConsumer(JOBS_TOPIC, bootstrap_servers=broker,
        group_id="elyrii-context-extractor-v1", enable_auto_commit=False,
        auto_offset_reset="earliest", max_poll_interval_ms=300000)
    producer = AIOKafkaProducer(bootstrap_servers=broker,
        value_serializer=lambda value: json.dumps(value).encode("utf-8"))
    try:
        await producer.start()
        await consumer.start()
        async with httpx.AsyncClient(base_url=os.getenv("EXTRACTION_AI_BASE_URL", os.getenv("AI_BASE_URL", "http://localhost:11434"))) as client:
            extractor = ContextExtractor(client, os.getenv("EXTRACTION_AI_MODEL", os.getenv("AI_MODEL", "mistral")))
            async def publish(user_id, result):
                await producer.send_and_wait(RESULTS_TOPIC, result, key=user_id.encode("utf-8"))
            async for message in consumer:
                await process_job(message.value, extractor, publish)
                # Only this processed record, never offsets for prefetched partitions.
                from aiokafka import TopicPartition
                await consumer.commit({TopicPartition(message.topic, message.partition): message.offset + 1})
    finally:
        await consumer.stop()
        await producer.stop()


async def main():
    while True:
        try:
            await run_worker()
        except Exception:
            logger.warning("Extraction worker disconnected; reconnecting")
            await asyncio.sleep(5)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(main())
