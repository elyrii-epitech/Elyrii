import { kafkaService } from "./chat.service";
import ChatRepository from "../../repository/chat.repository";
import { chatDelivery } from "./chat-delivery";
import { z } from "zod";

const repository = new ChatRepository();
const resultSchema = z.object({
    userId: z.uuid(), conversationId: z.string().min(1).max(200).default("default"),
    requestId: z.uuid(), response: z.string().min(1).max(100000),
    sourceMessageId: z.uuid(), sourceHash: z.string().regex(/^[a-f0-9]{64}$/),
});

/** Validate source ownership/currentness and commit before acknowledging delivery. */
export async function deliverAiResponse(raw: unknown) {
    const parsed = resultSchema.safeParse(raw);
    if (!parsed.success) return;
    const data = parsed.data;
    const saved = await repository.createCurrentResponse({
        userId: data.userId, conversationId: data.conversationId,
        role: "ai", message: data.response,
    }, data.sourceMessageId, data.sourceHash);
    chatDelivery.finish(data.requestId, data.userId, data.conversationId,
        saved ? "reply" : "error", saved?.message ?? "Ce message n’est plus disponible.",
        saved?.id, saved?.createdAt, data.sourceMessageId);
}
export async function handleAiResponse() {
    await kafkaService.consumer.subscribe({topic: "elyrii.ai.responses"});
    await kafkaService.consumer.run({eachMessage: async ({message}) => {
        if (!message.value || message.value.length > 500000) return;
        let data: unknown;
        try { data = JSON.parse(message.value.toString()); } catch { return; }
        // Let database failures propagate so Kafka can replay an uncommitted result.
        await deliverAiResponse(data);
    }});
}
