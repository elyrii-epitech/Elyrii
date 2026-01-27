export function checkEnvVars() {
    if (!Bun.env.CHAT_SERVICE_URL || !Bun.env.AUTH_SERVICE_URL || !Bun.env.JOURNAL_SERVICE_URL) {
        return null
    }

    return {
        CHAT_SERVICE_URL: Bun.env.CHAT_SERVICE_URL,
        AUTH_SERVICE_URL: Bun.env.AUTH_SERVICE_URL,
        JOURNAL_SERVICE_URL: Bun.env.JOURNAL_SERVICE_URL,
    }
}
