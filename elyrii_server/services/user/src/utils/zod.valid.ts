import { z } from "zod";

export const updateProfileValidation = z.object({
    firstName: z.string().min(1).optional(),
    lastName: z.string().min(1).optional(),
    age: z.number().min(0).max(150).optional(),
    pfp: z.string().url().optional(),
});

export type UpdateProfileType = z.infer<typeof updateProfileValidation>;
