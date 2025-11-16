import { kafkaService } from "./kafka.service";
import { CompressionTypes } from "kafkajs";
import { randomUUIDv7 } from "bun";

export async function sendMessageToTopic(userId: string, message: string) {

  await kafkaService.producer.send({
    compression: CompressionTypes.GZIP,
    topic: "elyrii.chat.messages",
    messages: [{
      key: randomUUIDv7(),
      value: JSON.stringify({ userId, message }),
      timestamp: Date.now().toString()
    }],
  });

}