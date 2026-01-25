import { kafkaService } from "./kafka.service";
import QuestRepository from "../repository/quest.repository";

const questRepository = new QuestRepository();

export async function initConsumers() {
    await kafkaService.consumer.subscribe({ topic: "elyrii.ai.quest-proposals", fromBeginning: false });

    await kafkaService.consumer.run({
        eachMessage: async ({ topic, partition, message }) => {
            if (!message.value) return;
            
            try {
                const payload = JSON.parse(message.value.toString());
                console.log(`[Kafka] Received message on ${topic}:`, payload);

                if (topic === "elyrii.ai.quest-proposals") {
                    await handleAiProposal(payload);
                }
            } catch (error) {
                console.error("[Kafka] Error processing message:", error);
            }
        },
    });
}

async function handleAiProposal(data: any) {
    // Validate data structure lightly (zod validation in repo/controller is better but let's do basic check)
    if (!data.userId || !data.title) {
        console.error("[Kafka] Invalid AI proposal data");
        return;
    }

    try {
        console.log(`[Kafka] Processing AI proposal for user ${data.userId}`);
        
        // 1. Create Template
        const template = await questRepository.createChallengeTemplate({
            title: data.title,
            description: data.description,
            source: 'AI',
            conditions: data.conditions || {},
            aggregator: data.aggregator || 'ALL',
            constraints: data.constraints || {}
        });

        // 2. Assign to User as PENDING
        await questRepository.assignChallengeToUser({
            userId: data.userId,
            challengeId: template.id,
            status: 'PENDING',
            progress: {}
        });

        console.log(`[Kafka] Successfully created AI proposal ${template.id} for user ${data.userId}`);
    } catch (error) {
        console.error("[Kafka] Failed to create AI proposal:", error);
    }
}
