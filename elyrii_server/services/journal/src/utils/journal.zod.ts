import { z } from "zod";

export const createEntriySchema = z.object({
    title: z.string().min(1).max(100),
    userId: z.string().min(1),
    content: z.string().min(1).nullable(),
    tags: z.array(z.string()).min(1).max(10).nullable(),
});

export const updateEntriySchema = createEntriySchema.partial();

export type CreateEntriySchemaType = z.infer<typeof createEntriySchema>;
export type UpdateEntriySchemaType = z.infer<typeof updateEntriySchema>;