import { Kafka } from "kafkajs";
import { resolveKafkaBroker } from "../utils/kafka-broker.utils";

const broker = resolveKafkaBroker(Bun.env);

const kafka = new Kafka({
    clientId: "elyrii-server",
    brokers: [broker]
});

export const producer = kafka.producer();
export const chatConsumer = kafka.consumer({ groupId: "chat-service" });
export const questConsumer = kafka.consumer({ groupId: "quest-service" });

export const initKafka = async () => {
    try {
        console.log(`[Kafka] Connecting to ${broker}...`);
        await producer.connect();
        await chatConsumer.connect();
        await questConsumer.connect();
        console.log("[Kafka] Connected successfully");
    } catch (error) {
        console.error("[Kafka] Connection failed", error);
        throw error;
    }
}

export const kafkaService = {
    producer,
    chatConsumer,
    questConsumer
}
