/** Preserve plain-text replies for old clients; new clients opt into correlation. */
export function chatResponse(
    type: "reply" | "error",
    message: string,
    conversationId: string,
    requestId?: string,
): string {
    return requestId
        ? JSON.stringify({ type, requestId, conversationId, message })
        : message;
}
