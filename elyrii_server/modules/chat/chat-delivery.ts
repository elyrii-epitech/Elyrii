import type { WSContext } from "hono/ws";

type Pending = { userId: string; conversationId: string; sourceMessageId: string; requestId: string; socket: WSContext; timer: ReturnType<typeof setTimeout> };
/** Only the originating socket can receive a terminal result. No user-wide broadcast. */
export class ChatDelivery {
    private pending = new Map<string, Pending>();
    constructor(private readonly timeout = 45000) {}
    register(key: string, input: Omit<Pending, "timer">) {
        if (this.pending.has(key)) throw new Error("Duplicate dispatch key");
        if ([...this.pending.values()].filter(p => p.socket === input.socket).length >= 8) throw new Error("Too many pending messages");
        const timer = setTimeout(() => this.finish(key, input.userId, input.conversationId, "error", "La réponse prend trop de temps. Réessaie."), this.timeout);
        this.pending.set(key, {...input, timer});
    }
    finish(key: string, userId: string, conversationId: string, type: "reply" | "error", message: string, messageId?: string, createdAt?: Date, sourceMessageId?: string) {
        const pending = this.pending.get(key);
        if (!pending || pending.userId !== userId || pending.conversationId !== conversationId ||
            (sourceMessageId && pending.sourceMessageId !== sourceMessageId)) return false;
        this.pending.delete(key);
        clearTimeout(pending.timer);
        if (pending.socket.readyState === WebSocket.OPEN) {
            try { pending.socket.send(JSON.stringify({type, requestId: pending.requestId, conversationId, message,
                messageId, createdAt: createdAt?.toISOString()})); } catch { /* Disconnected; history retains the reply. */ }
        }
        return true;
    }
    cancelSocket(socket: WSContext) {
        for (const [key, pending] of this.pending) if (pending.socket === socket) {
            clearTimeout(pending.timer);
            this.pending.delete(key);
        }
    }
}
export const chatDelivery = new ChatDelivery();
