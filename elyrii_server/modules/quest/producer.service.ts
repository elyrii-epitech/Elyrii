import { producer } from "../../config/kafka.config";
import { CompressionTypes } from "kafkajs";

export async function sendQuestEvent(eventType: string, payload: any) {
    try {
        await producer.send({
            compression: CompressionTypes.GZIP,
            topic: "elyrii.quest.events",
            messages: [{
                key: eventType,
                value: JSON.stringify({
                    eventType,
                    timestamp: new Date().toISOString(),
                    ...payload
                }),
            }],
        });
        console.log(`[Kafka] Sent event: ${eventType}`);
    } catch (error) {
        console.error(`[Kafka] Failed to send event ${eventType}:`, error);
    }
}
