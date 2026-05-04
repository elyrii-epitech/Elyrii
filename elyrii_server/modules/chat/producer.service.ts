import { kafkaService } from "./chat.service";
import { CompressionTypes } from "kafkajs";
import { randomUUIDv7 } from "bun";

/**
 * Sends a chat message to the Kafka topic.
 * 
 * @remarks
 * Produces a message to the `elyrii.chat.messages` topic.
 * The message is compressed using GZIP.
 * 
 * @param userId - The ID of the user sending the message
 * @param message - The content of the message
 */
export async function sendMessageToTopic(
  userId: string,
  message: string,
  options?: {
    conversationId?: string;
    history?: Array<{ role: string; message: string }>;
  }
) {

  await kafkaService.producer.send({
    compression: CompressionTypes.GZIP,
    topic: "elyrii.chat.messages",
    messages: [{
      key: randomUUIDv7(),
      value: JSON.stringify({
        userId,
        message,
        conversationId: options?.conversationId ?? "default",
        history: options?.history ?? [],
      }),
      timestamp: Date.now().toString()
    }],
  });

}
