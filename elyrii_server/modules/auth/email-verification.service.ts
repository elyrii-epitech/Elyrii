export interface VerificationMailer {
    available(): boolean;
    send(email: string, token: string): Promise<void>;
}

/** Same server-to-mail-provider boundary as password recovery; no client secret. */
export class WebhookVerificationMailer implements VerificationMailer {
    constructor(private readonly deliver: (input: URL, init: RequestInit) => Promise<Response> = fetch) {}

    private configuration() {
        const endpoint = new URL(Bun.env.EMAIL_VERIFICATION_MAIL_WEBHOOK ?? Bun.env.PASSWORD_RESET_MAIL_WEBHOOK ?? "");
        const secret = Bun.env.EMAIL_VERIFICATION_MAIL_SECRET ?? Bun.env.PASSWORD_RESET_MAIL_SECRET;
        const publicUrl = new URL(Bun.env.PUBLIC_URL ?? "");
        if (endpoint.protocol !== "https:" || endpoint.username || endpoint.password || endpoint.search || endpoint.hash || !secret ||
            publicUrl.protocol !== "https:" || publicUrl.username || publicUrl.password || publicUrl.search || publicUrl.hash) {
            throw new Error("Email verification is not configured");
        }
        return {endpoint, secret, publicUrl};
    }

    available(): boolean {
        try { this.configuration(); return true; } catch { return false; }
    }

    async send(email: string, token: string): Promise<void> {
        const {endpoint, secret, publicUrl} = this.configuration();
        const link = new URL(`${publicUrl.toString().replace(/\/$/, "")}/auth/verify-email`);
        // Fragments never enter gateway request logs or Referer headers.
        link.hash = token;
        const response = await this.deliver(endpoint, {
            method: "POST", redirect: "error", signal: AbortSignal.timeout(10000),
            headers: {"Content-Type": "application/json", Authorization: `Bearer ${secret}`},
            body: JSON.stringify({template: "email-verification", to: email, verificationUrl: link.toString(), expiresInMinutes: 1440}),
        });
        if (!response.ok) throw new Error("Email verification delivery failed");
    }
}
