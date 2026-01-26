import { Kafka } from "kafkajs";

// Remove protocol if present for kafkajs brokers
const broker = process.env.REDPANDA_URL?.replace(/^https?:\/\//, "") || "redpanda:9092";

const kafka = new Kafka({
    clientId: "quest-service",
    brokers: [broker]
});

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: "quest-service" });

export const initKafka = async () => {
    try {
        console.log(`[Kafka] Connecting to ${broker}...`);
        await producer.connect();
        await consumer.connect();
        console.log("[Kafka] Connected successfully");
    } catch (error) {
        console.error("[Kafka] Connection failed", error);
        throw error;
    }
}

export const kafkaService = {
    producer,
    consumer
}
