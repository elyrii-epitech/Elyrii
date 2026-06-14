"""
Kafka consumer/producer bridge for Elyrii AI.
Listens to user messages from Kafka and generates responses using the AI model.
"""

import json
import logging
import os
import asyncio
from typing import Dict, Any, List

from aiokafka import AIOKafkaConsumer, AIOKafkaProducer
import httpx
from prompt.system_prompt import get_system_prompt

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
        logger.info(f"Initialized with System Prompt: {self.system_prompt[:50]}...")

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

    async def process_message(self, data: Dict[str, Any], request_id: str = None):
        user_id = data.get("userId")
        message = data.get("message")
        conversation_id = data.get("conversationId", "default")
        history = data.get("history", [])

        if not user_id or not message:
            return

        logger.info(f"Processing message for user {user_id} (request_id: {request_id})")

        try:
            # Prepare messages for Ollama
            ollama_messages = [
                {"role": "system", "content": self.system_prompt}
            ]
            for h in history:
                role = "assistant" if h.get("role") == "ai" else h.get("role")
                ollama_messages.append({"role": role, "content": h.get("message")})
            
            ollama_messages.append({"role": "user", "content": message})

            # Call Ollama
            response = await self.client.post("/api/chat", json={
                "model": AI_MODEL,
                "messages": ollama_messages,
                "stream": False
            })
            response.raise_for_status()
            ai_response = response.json()["message"]["content"]

            # Produce response
            await self.producer.send_and_wait(AI_RESPONSES_TOPIC, {
                "userId": user_id,
                "response": ai_response,
                "conversationId": conversation_id,
                "requestId": request_id
            })
            logger.info(f"Sent AI response for user {user_id}")

        except Exception as e:
            logger.error(f"Error processing message: {e}", exc_info=True)

if __name__ == "__main__":
    bridge = AiBridge()
    asyncio.run(bridge.start())
