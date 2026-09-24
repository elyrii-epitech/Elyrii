import { kafkaService } from "./chat.service";
import ChatRepository from "../../repository/chat.repository";
import { aiResponseTracker } from "./response-tracker.utils";

const chatRepository = new ChatRepository();

/**
 * Persists AI responses and resolves the matching controller request.
 * 
 * @remarks
 * Listens to the `elyrii.ai.responses` topic.
 * When a message is received, it parses the JSON content to find the `userId` and `response`.
 * Only the originating controller sends the terminal WebSocket response.
 * A result arriving after its timeout is persisted, but never broadcast to a
 * different request or a replacement socket belonging to the same user.
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
        }
    });

}
