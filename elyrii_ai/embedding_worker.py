"""Embedding-only Kafka worker with publish-before-offset-commit semantics."""
import asyncio
import json
import logging
import os
import httpx

try:
    from .embeddings import EmbeddingJob, OllamaEmbeddingAdapter, ModelMismatch, InvalidEmbeddingInput, model_spec
    from .extraction import strict_json
except ImportError:
    from embeddings import EmbeddingJob, OllamaEmbeddingAdapter, ModelMismatch, InvalidEmbeddingInput, model_spec
    from extraction import strict_json

JOBS_TOPIC = "elyrii.context.embeddings.jobs.v1"
RESULTS_TOPIC = "elyrii.context.embeddings.results.v1"


async def process_job(raw, adapter, publish):
    if len(raw) > 65536:
        return
    try:
        job = EmbeddingJob.model_validate(strict_json(raw))
    except (ValueError, TypeError, RecursionError):
        return
    # Each immutable version has its own consumer group and ignores other versions.
    if job.spec != adapter.spec:
        return
    result = job.model_dump(exclude={"spec", "content"})
    try:
        vector = await adapter.embed(job.content)
        result.update(status="success", dimensions=adapter.spec.dimensions, embedding=vector)
    except ModelMismatch:
        result.update(status="failure", error="model_mismatch")
    except InvalidEmbeddingInput:
        result.update(status="failure", error="invalid_input")
    except Exception:
        result.update(status="failure", error="provider_failed")
    await publish(job.userId, result)


async def run_worker(spec):
    from aiokafka import AIOKafkaConsumer, AIOKafkaProducer, TopicPartition
    broker = os.getenv("KAFKA_BROKER", "localhost:9092")
    consumer = AIOKafkaConsumer(JOBS_TOPIC, bootstrap_servers=broker, group_id=f"elyrii-embedding-worker-{spec.digest}",
        enable_auto_commit=False, auto_offset_reset="earliest", max_poll_interval_ms=300000)
    producer = AIOKafkaProducer(bootstrap_servers=broker, value_serializer=lambda value: json.dumps(value).encode())
    try:
        await producer.start()
        await consumer.start()
        async with httpx.AsyncClient(base_url=os.getenv("EMBEDDING_AI_BASE_URL", os.getenv("AI_BASE_URL", "http://localhost:11434"))) as client:
            adapter = OllamaEmbeddingAdapter(client, spec)
            async def publish(user_id, result):
                await producer.send_and_wait(RESULTS_TOPIC, result, key=user_id.encode())
            async for message in consumer:
                await process_job(message.value, adapter, publish)
                await consumer.commit({TopicPartition(message.topic, message.partition): message.offset + 1})
    finally:
        await consumer.stop()
        await producer.stop()


async def main():
    spec = model_spec(os.environ["EMBEDDING_MODEL_DIGEST"])
    while True:
        try:
            await run_worker(spec)
        except Exception:
            logging.warning("Embedding worker disconnected; reconnecting")
            await asyncio.sleep(5)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(main())
