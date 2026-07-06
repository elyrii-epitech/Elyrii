function sanitizeBroker(value?: string): string | null {
    if (!value) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    return trimmed.replace(/^https?:\/\//, "");
}

export function resolveKafkaBroker(env: Record<string, string | undefined>): string {
    const fromExplicitUrl =
        sanitizeBroker(env.REDPANDA_URL) ||
        sanitizeBroker(env.KAFKA_BROKER_URL) ||
        sanitizeBroker(env.KAFKA_BROKER);
    if (fromExplicitUrl) return fromExplicitUrl;

    const host = sanitizeBroker(env.REDPANDA_HOST);
    const port = (env.REDPANDA_PORT || "").trim();
    if (host && port) {
        return `${host}:${port}`;
    }

    const runningInDocker =
        env.DOCKER_ENV === "true" ||
        env.RUNNING_IN_DOCKER === "true" ||
        env.CONTAINER === "true";
    return runningInDocker ? "redpanda:9092" : "localhost:9092";
}
