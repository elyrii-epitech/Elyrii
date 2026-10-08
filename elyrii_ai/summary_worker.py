"""Independent Kafka transport for rolling summaries; no response-prompt changes."""
import asyncio
import json
import logging
import os

import httpx

try:
    from .summary import RollingSummarizer, SummaryJob, SummaryInputTooLarge
    from .extraction import strict_json
except ImportError:
    from summary import RollingSummarizer, SummaryJob, SummaryInputTooLarge
    from extraction import strict_json

JOBS_TOPIC = "elyrii.context.summary.jobs.v1"
RESULTS_TOPIC = "elyrii.context.summary.results.v1"


async def process_job(raw, summarizer, publish):
    if len(raw) > 250000:
        return
    try:
        job = SummaryJob.model_validate(strict_json(raw))
    except (ValueError, TypeError, KeyError, RecursionError):
        return
    result = {key: getattr(job, key) for key in ("version", "jobId", "userId", "conversationId", "revision", "attempt", "model")}
    try:
        if job.model != summarizer.model:
            result.update(status="failure", error="invalid_input")
        else:
            result.update(await summarizer.summarize(job))
    except SummaryInputTooLarge:
        result.update(status="failure", error="input_too_large")
    except Exception:
        result.update(status="failure", error="inference_failed")
    await publish(job.userId, result)


async def run_worker(tokenizer):
    from aiokafka import AIOKafkaConsumer, AIOKafkaProducer, TopicPartition
    broker = os.getenv("KAFKA_BROKER", "localhost:9092")
    consumer = AIOKafkaConsumer(JOBS_TOPIC, bootstrap_servers=broker, group_id="elyrii-summary-worker-v1",
        enable_auto_commit=False, auto_offset_reset="earliest", max_poll_interval_ms=300000)
    producer = AIOKafkaProducer(bootstrap_servers=broker, value_serializer=lambda data: json.dumps(data).encode())
    try:
        await producer.start()
        await consumer.start()
        async with httpx.AsyncClient(base_url=os.getenv("SUMMARY_AI_BASE_URL", os.getenv("AI_BASE_URL", "http://localhost:11434"))) as client:
            summarizer = RollingSummarizer(client, os.getenv("SUMMARY_AI_MODEL", os.getenv("AI_MODEL", "mistral")), tokenizer)
            async def publish(user_id, result):
                await producer.send_and_wait(RESULTS_TOPIC, result, key=user_id.encode())
            async for message in consumer:
                await process_job(message.value, summarizer, publish)
                await consumer.commit({TopicPartition(message.topic, message.partition): message.offset + 1})
    finally:
        await consumer.stop()
        await producer.stop()


async def main():
    from tokenizers import Tokenizer
    # Fail startup on missing/invalid tokenizer; never silently approximate counts.
    tokenizer = Tokenizer.from_file(os.environ["SUMMARY_TOKENIZER_PATH"])
    tokenizer.no_truncation()
    tokenizer.no_padding()
    while True:
        try:
            await run_worker(tokenizer)
        except Exception:
            logging.warning("Summary worker disconnected; reconnecting")
            await asyncio.sleep(5)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(main())
