import { z } from "zod";

export const createEntriySchema = z.object({
    title: z.string().min(1).max(100),
    userId: z.string().optional(),
    content: z.string().optional().nullable(),
    tags: z.array(z.string()).max(10).optional().nullable(),
});


export const updateEntrySchema = createEntriySchema.partial();

export type CreateEntriySchemaType = z.infer<typeof createEntriySchema>;
export type UpdateEntrySchemaType = z.infer<typeof updateEntrySchema>;