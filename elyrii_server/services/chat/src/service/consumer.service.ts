import { clientSockets } from "../../index";
import { kafkaService } from "./kafka.service";

/**
 * Subscribes to AI responses from Kafka and forwards them to connected clients.
 * 
 * @remarks
 * Listens to the `elyrii.ai.responses` topic.
 * When a message is received, it parses the JSON content to find the `userId` and `response`.
 * If the user is connected via WebSocket (found in `clientSockets`), the AI response is sent to them.
 */
export async function handleAiResponse() {
    await kafkaService.consumer.subscribe({ topic: "elyrii.ai.responses" });

    await kafkaService.consumer.run({
        eachMessage: async ({ message }) => {
            if (!message.value) return;
            const data: { userId: string, response: string } = JSON.parse(message.value.toString());
            const { userId, response } = data;
            const ws = clientSockets.get(userId);

            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ from: "ai", message: response }));
            }
        }
    });

}
