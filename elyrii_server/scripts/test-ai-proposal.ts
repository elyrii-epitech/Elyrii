import { Kafka, CompressionTypes } from "kafkajs";

const KAFKA_BROKER = process.env.KAFKA_BROKER || "localhost:9092";

async function run() {
    const kafka = new Kafka({
        clientId: "test-ai-proposer",
        brokers: [KAFKA_BROKER],
    });

    const producer = kafka.producer();
    await producer.connect();

    const userId = "00000000-0000-0000-0000-000000000001"; // Mock user ID

    console.log("Sending AI response and quest proposal...");

    // 1. Simulate the text response
    await producer.send({
        topic: "elyrii.ai.responses",
        messages: [{
            value: JSON.stringify({
                userId,
                response: "I've noticed you've been feeling a bit overwhelmed lately. How about we try a small challenge to help you stay mindful?",
                conversationId: "default",
                requestId: "test-request-id"
            })
        }]
    });

    // 2. Simulate the quest proposal (normally sent by the bridge)
    await producer.send({
        topic: "elyrii.ai.quest-proposals",
        messages: [{
            value: JSON.stringify({
                userId,
                title: "Mindful Moments",
                description: "Log your mood 3 times this week to build mindfulness.",
                conditions: [
                    { type: "mood_count", target: 3, period: "week" }
                ],
                aggregator: "ALL"
            })
        }]
    });

    console.log("Done. Check the database and pending proposals API.");
    await producer.disconnect();
}

run().catch(console.error);
