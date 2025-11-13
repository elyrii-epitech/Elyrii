import { Kafka } from "kafkajs";

const kafka = new Kafka({ brokers: ["localhost:9092"]})

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: "chat-service" });

export const initKafka = async () => {
    await producer.connect();
    await consumer.connect();
}

export const kafkaService = {
    producer,
    consumer
}
