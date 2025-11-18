import { clientSockets } from "../../index";
import { kafkaService } from "./kafka.service";

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
