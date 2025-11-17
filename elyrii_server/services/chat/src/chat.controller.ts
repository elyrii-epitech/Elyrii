import { createFactory } from "hono/factory";

const factory = createFactory()

export const chatHistory = factory.createHandlers(async (ctx) => {
    return ctx.json({message: "Hello"});
})
