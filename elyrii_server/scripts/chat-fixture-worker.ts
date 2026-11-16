import { Kafka, CompressionTypes } from "kafkajs";
import { createHash } from "node:crypto";
if (Bun.env.CHAT_INTEGRATION !== "1" || Bun.env.NODE_ENV !== "test" ||
    !Bun.env.KAFKA_BROKER?.startsWith("127.0.0.1:")) throw new Error("Local fixture only");
const kafka = new Kafka({clientId: "chat-fixture", brokers: [Bun.env.KAFKA_BROKER], logLevel: 1});
const consumer = kafka.consumer({groupId: "chat-integration-ai"});
const producer = kafka.producer();
const admin = kafka.admin();
await admin.connect();
await admin.createTopics({waitForLeaders: true, topics: [
    "elyrii.chat.messages", "elyrii.ai.responses", "elyrii.ai.quest-proposals",
    "elyrii.context.extraction.jobs.v1", "elyrii.context.extraction.results.v1",
].map(topic => ({topic, numPartitions: 1, replicationFactor: 1}))});
await admin.disconnect();
await producer.connect();
await consumer.connect();
await consumer.subscribe({topic: "elyrii.chat.messages", fromBeginning: true});
consumer.on(consumer.events.GROUP_JOIN, () => { void Bun.write(Bun.env.CHAT_FIXTURE_READY!, "ready"); });
await consumer.run({eachMessage: async ({message}) => {
    const data = JSON.parse(message.value!.toString());
    if (data.message.startsWith("[ignore]")) return;
    const result = {userId: data.userId, conversationId: data.conversationId,
        requestId: message.key!.toString(), sourceMessageId: data.sourceMessageId,
        sourceHash: createHash("sha256").update(data.message).digest("hex"),
        response: "Je suis là pour t’écouter. Prenons un moment ensemble."};
    const publish = () => producer.send({topic: "elyrii.ai.responses", compression: CompressionTypes.GZIP,
        messages: [{key: message.key, value: JSON.stringify(result)}]});
    if (data.message.startsWith("[slow]")) setTimeout(() => { void publish(); }, 500);
    else await publish();
}});
