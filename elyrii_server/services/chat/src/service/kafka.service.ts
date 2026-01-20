import { Kafka } from "kafkajs";

const kafka = new Kafka({ brokers: ["redpanda:9092"]})

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: "chat-service" });

export const initKafka = async () => {
    try {
        await producer.connect();
        await consumer.connect();
    } catch (error) {
        console.error(error);
        throw error;
    }
}

export const kafkaService = {
    producer,
    consumer
}
