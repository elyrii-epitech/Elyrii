import { z } from "zod";
export const contextPageSchema = z.strictObject({
    limit: z.coerce.number().int().min(1).max(100).default(25),
    after: z.uuid().optional(),
    status: z.enum(["active", "superseded", "deleted"]).optional(),
});
export const correctFactSchema = z.strictObject({ value: z.json().refine(v => v !== null) });
export const correctMemorySchema = z.strictObject({ content: z.string().trim().min(1).max(10000) });
