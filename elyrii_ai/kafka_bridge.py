"""
Kafka consumer/producer bridge for Elyrii AI.
Listens to user messages from Kafka and generates responses using the AI model.
"""

import json
import hashlib
import logging
import os
import asyncio
from typing import Dict, Any, List

from aiokafka import AIOKafkaConsumer, AIOKafkaProducer
import httpx
try:
    from .prompt.system_prompt import get_system_prompt
    from .chat_context import NativePromptBudget, InputTooLarge, safe_sections, bounded_json, verify_generation_model, metric
except ImportError:
    from prompt.system_prompt import get_system_prompt
    from chat_context import NativePromptBudget, InputTooLarge, safe_sections, bounded_json, verify_generation_model, metric
import time

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# Kafka Configuration
KAFKA_BROKER = os.getenv("KAFKA_BROKER", "localhost:9092")
CHAT_MESSAGES_TOPIC = "elyrii.chat.messages"
AI_RESPONSES_TOPIC = "elyrii.ai.responses"

# AI Configuration
AI_BASE_URL = os.getenv("AI_BASE_URL", "http://localhost:11434") # Default to Ollama
AI_MODEL = os.getenv("AI_MODEL", "mistral")
PROMPT_VERSION = int(os.getenv("PROMPT_VERSION", "1"))

class AiBridge:
    def __init__(self):
        self.consumer: AIOKafkaConsumer = None
        self.producer: AIOKafkaProducer = None
        self.client = httpx.AsyncClient(base_url=AI_BASE_URL, timeout=300.0)
        self.system_prompt = get_system_prompt(PROMPT_VERSION)
        self.context_enabled = os.getenv("ENABLE_PERSISTENT_CONTEXT", "false") == "true"
        self.budget = None
        self.context_client = httpx.AsyncClient(base_url=os.getenv("CONTEXT_SERVER_URL", "http://localhost:3000"), timeout=5.0)
        if self.context_enabled:
            try:
                self.budget = NativePromptBudget.load(os.environ["CHAT_TOKENIZER_DIR"], AI_MODEL)
            except Exception:
                logger.error("Context generation artifacts unavailable; budgeted inference disabled")

    async def start(self):
        logger.info(f"Connecting to Kafka broker: {KAFKA_BROKER}")
        self.consumer = AIOKafkaConsumer(
            CHAT_MESSAGES_TOPIC,
            bootstrap_servers=KAFKA_BROKER,
            group_id="elyrii-ai-bridge",
            value_deserializer=lambda v: json.loads(v.decode("utf-8"))
        )
        self.producer = AIOKafkaProducer(
            bootstrap_servers=KAFKA_BROKER,
            value_serializer=lambda v: json.dumps(v).encode("utf-8")
        )

        await self.consumer.start()
        await self.producer.start()
        logger.info(f"Kafka bridge started. Using AI at {AI_BASE_URL} with model {AI_MODEL}")

        try:
            async for msg in self.consumer:
                # Get requestId from message key if present
                request_id = msg.key.decode("utf-8") if msg.key else None
                await self.process_message(msg.value, request_id)
        finally:
            await self.stop()

    async def stop(self):
        if self.consumer:
            await self.consumer.stop()
        if self.producer:
            await self.producer.stop()
        await self.client.aclose()
        await self.context_client.aclose()

    async def process_message(self, data: Dict[str, Any], request_id: str = None):
        user_id = data.get("userId")
        message = data.get("message")
        conversation_id = data.get("conversationId", "default")
        history = data.get("history", [])

        if not user_id or not message:
            return

        started = time.monotonic()
        async def publish(text):
            await self.producer.send_and_wait(AI_RESPONSES_TOPIC, {"userId": user_id, "response": text,
                "conversationId": conversation_id, "requestId": request_id,
                "sourceMessageId": data.get("sourceMessageId"), "sourceHash": hashlib.sha256(message.encode()).hexdigest()})
        try:
            if self.context_enabled:
                if self.budget is None:
                    await publish("Le service est temporairement indisponible. Réessayez dans un instant.")
                    metric("generation", started, "configuration_failure")
                    return
                sections = None
                envelope = data.get("context")
                if envelope:
                    refresh_started = time.monotonic()
                    try:
                        fresh = await asyncio.wait_for(bounded_json(self.context_client, "POST", "/internal/chat-context/refresh",
                            {"ticket": envelope["ticket"]}), timeout=5.0)
                        identity = {"userId": user_id, "conversationId": conversation_id, "sourceMessageId": data.get("sourceMessageId")}
                        if any(fresh.get(k) != v for k, v in identity.items()): raise ValueError("Identity mismatch")
                        message = fresh["query"]
                        if fresh.get("sections") is not None:
                            sections = safe_sections(fresh, identity)
                        metric("refresh", refresh_started, "ok" if sections is not None else "ordinary_fallback")
                    except Exception:
                        # Never use stale Kafka sections/history when validation fails.
                        metric("refresh", refresh_started, "unavailable")
                        await publish("Ce message n’est plus disponible ou n’a pas pu être vérifié. Envoyez un nouveau message.")
                        return
                composition_started = time.monotonic()
                body, counts = self.budget.compose(self.system_prompt, message, sections)
                metric("composition", composition_started, "ok", **counts)
                generation_started = time.monotonic()
                await asyncio.wait_for(verify_generation_model(self.client, self.budget), timeout=5.0)
                generated = await asyncio.wait_for(bounded_json(self.client, "POST", "/api/generate", body, limit=200000), timeout=300.0)
                if generated.get("done") is not True or not isinstance(generated.get("response"), str): raise ValueError("Invalid generation")
                # Compare provider measurements with the configured window as an operational guard.
                if generated.get("prompt_eval_count", counts["inputTokens"]) + self.budget.response_tokens > self.budget.window:
                    raise ValueError("Provider token accounting mismatch")
                await asyncio.wait_for(verify_generation_model(self.client, self.budget), timeout=5.0)
                ai_response = generated["response"]
                metric("generation", generation_started, "ok", outputTokens=generated.get("eval_count", 0))
            else:
                ollama_messages = [{"role": "system", "content": self.system_prompt}]
                for h in history:
                    role = "assistant" if h.get("role") == "ai" else h.get("role")
                    if role in ("user", "assistant") and isinstance(h.get("message"), str):
                        ollama_messages.append({"role": role, "content": h["message"]})
                ollama_messages.append({"role": "user", "content": message})
                response = await self.client.post("/api/chat", json={"model": AI_MODEL, "messages": ollama_messages, "stream": False})
                response.raise_for_status()
                ai_response = response.json()["message"]["content"]
            await publish(ai_response)
        except InputTooLarge:
            metric("composition", started, "input_too_large")
            await publish("Votre message est trop long pour être traité en entier. Raccourcissez-le ou envoyez-le en plusieurs parties.")
        except Exception:
            metric("generation", started, "failure")
            await publish("Une erreur temporaire empêche la réponse. Réessayez dans un instant.")

if __name__ == "__main__":
    bridge = AiBridge()
    asyncio.run(bridge.start())
