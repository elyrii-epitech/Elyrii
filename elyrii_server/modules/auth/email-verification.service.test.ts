import { afterEach, expect, test } from "bun:test";
import { WebhookVerificationMailer } from "./email-verification.service";

const keys = ["EMAIL_VERIFICATION_MAIL_WEBHOOK", "EMAIL_VERIFICATION_MAIL_SECRET", "PASSWORD_RESET_MAIL_WEBHOOK", "PASSWORD_RESET_MAIL_SECRET", "PUBLIC_URL"] as const;
const previous = Object.fromEntries(keys.map(key => [key, Bun.env[key]]));
afterEach(() => {
    for (const key of keys) {
        if (previous[key] === undefined) delete Bun.env[key]; else Bun.env[key] = previous[key];
    }
});
test("verification mail contains a fragment link and uses the configured HTTPS delivery boundary", async () => {
    Bun.env.EMAIL_VERIFICATION_MAIL_WEBHOOK = "https://mail.example.test/send";
    Bun.env.EMAIL_VERIFICATION_MAIL_SECRET = "fixture-only";
    Bun.env.PUBLIC_URL = "https://api.example.test";
    let delivered = false;
    const mailer = new WebhookVerificationMailer(async (url, options) => {
        expect(url.toString()).toBe("https://mail.example.test/send");
        expect(options.redirect).toBe("error");
        expect(options.headers).toMatchObject({Authorization: "Bearer fixture-only"});
        const body = JSON.parse(options.body as string);
        const link = new URL(body.verificationUrl);
        expect(link.pathname).toBe("/auth/verify-email");
        expect(link.search).toBe("");
        expect(link.hash).toBe("#fixture-token.secret");
        expect(body.template).toBe("email-verification");
        delivered = true;
        return new Response(null, {status: 202});
    });
    expect(mailer.available()).toBe(true);
    await mailer.send("fixture@example.test", "fixture-token.secret");
    expect(delivered).toBe(true);
});
test("missing or unsafe mail configuration cannot claim to send an activation email", () => {
    for (const key of keys) delete Bun.env[key];
    const mailer = new WebhookVerificationMailer();
    expect(mailer.available()).toBe(false);
    Bun.env.EMAIL_VERIFICATION_MAIL_WEBHOOK = "http://mail.example.test/send";
    Bun.env.EMAIL_VERIFICATION_MAIL_SECRET = "fixture";
    Bun.env.PUBLIC_URL = "https://api.example.test";
    expect(mailer.available()).toBe(false);
});
