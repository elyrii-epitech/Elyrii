import { Kafka } from "kafkajs";
import { resolveKafkaBroker } from "../../utils/kafka-broker.utils";
import { ExtractionRepository } from "../../repository/extraction.repository";
import { EXTRACTION_JOBS_TOPIC, EXTRACTION_RESULTS_TOPIC, RESULT_LIMIT_BYTES } from "./extraction.contracts";

/** Independent Kafka clients: extraction connection failures never gate chat startup. */
export function startExtractionService() {
    const kafka = new Kafka({ clientId: "elyrii-context", brokers: [resolveKafkaBroker(Bun.env)],
        connectionTimeout: 5000, requestTimeout: 10000, retry: { retries: 2 } });
    const producer = kafka.producer();
    const consumer = kafka.consumer({ groupId: "elyrii-context-results-v1" });
    const repository = new ExtractionRepository();
    let stopped = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let reconnectTimer: ReturnType<typeof setTimeout> | undefined;
    let polling = false;
    let connecting = false;
    const tick = async () => {
        try {
            for (let count = 0; count < 20 && !stopped; count++) {
                if (!await repository.publishNext(async job => {
                    await producer.send({ topic: EXTRACTION_JOBS_TOPIC,
                        messages: [{ key: job.userId, value: JSON.stringify(job) }] });
                })) break;
            }
        } catch { console.error("[Context] Outbox poll failed; pending jobs remain durable"); }
        if (!stopped) timer = setTimeout(tick, 1000);
    };
    const connect = async () => {
        if (connecting || stopped) return;
        connecting = true;
        try {
            await producer.connect();
            await consumer.connect();
            await consumer.subscribe({ topic: EXTRACTION_RESULTS_TOPIC, fromBeginning: true });
            await consumer.run({ eachMessage: async ({ message }) => {
                if (!message.value || message.value.length > RESULT_LIMIT_BYTES) return;
                let payload: unknown;
                try { payload = JSON.parse(message.value.toString()); } catch { return; }
                // Let DB errors propagate: the offset must not commit before reconciliation.
                await repository.complete(payload);
            } });
            if (!stopped && !polling) { polling = true; void tick(); }
        } catch {
            console.error("[Context] Kafka unavailable; reconnecting independently of chat");
            if (!stopped) reconnectTimer = setTimeout(connect, 5000);
        } finally {
            connecting = false;
        }
    };
    consumer.on(consumer.events.CRASH, ({ payload }) => {
        if (!stopped && !payload.restart) {
            // KafkaJS restarts retriable failures itself. Recover non-retriable
            // handler failures too, retaining uncommitted results for replay.
            if (reconnectTimer) clearTimeout(reconnectTimer);
            reconnectTimer = setTimeout(async () => {
                try { await consumer.disconnect(); } catch { /* reconnect below */ }
                void connect();
            }, 5000);
        }
    });
    void connect();
    return async () => {
        stopped = true;
        if (timer) clearTimeout(timer);
        if (reconnectTimer) clearTimeout(reconnectTimer);
        await Promise.allSettled([consumer.disconnect(), producer.disconnect()]);
    };
}
