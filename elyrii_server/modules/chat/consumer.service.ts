import { clientSockets } from "../../main";
import { kafkaService } from "./chat.service";
import ChatRepository from "../../repository/chat.repository";
import { aiResponseTracker } from "./response-tracker.utils";

const chatRepository = new ChatRepository();

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
            const data: { userId: string, response: string, conversationId?: string, requestId?: string } = JSON.parse(message.value.toString());
            const { userId, response, requestId } = data;
            const conversationId = data.conversationId ?? "default";

            // Resolve pending promise if anyone is waiting for this requestId
            if (requestId) {
                aiResponseTracker.resolveResponse(requestId, response);
            }

            try {
                await chatRepository.createMessage({
                    userId,
                    conversationId,
                    role: "ai",
                    message: response,
                });
            } catch (error) {
                console.error("Failed to persist AI chat message:", error);
            }
            const ws = clientSockets.get(userId);

            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(response);
            }
        }
    });

}
