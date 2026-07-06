import { describe, expect, test } from "bun:test";
import { resolveKafkaBroker } from "./kafka-broker.utils";

describe("resolveKafkaBroker", () => {
    test("uses REDPANDA_URL when provided", () => {
        const broker = resolveKafkaBroker({ REDPANDA_URL: "http://redpanda:9092" });
        expect(broker).toBe("redpanda:9092");
    });

    test("uses host and port when provided", () => {
        const broker = resolveKafkaBroker({
            REDPANDA_HOST: "localhost",
            REDPANDA_PORT: "19092",
        });
        expect(broker).toBe("localhost:19092");
    });

    test("defaults to localhost outside docker", () => {
        const broker = resolveKafkaBroker({});
        expect(broker).toBe("localhost:9092");
    });

    test("defaults to redpanda in docker", () => {
        const broker = resolveKafkaBroker({ DOCKER_ENV: "true" });
        expect(broker).toBe("redpanda:9092");
    });
});
