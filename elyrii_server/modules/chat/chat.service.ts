import { producer, chatConsumer, initKafka } from "../../config/kafka.config";

export const kafkaService = {
    producer,
    consumer: chatConsumer
};

export { initKafka, producer, chatConsumer as consumer };
