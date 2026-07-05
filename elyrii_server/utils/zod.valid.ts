import z from "zod";

export const registerValidation = z.object({
    email: z.email(),
    password: z.string().min(6),
    lastName: z.string().min(1),
    firstName: z.string().min(1),
    age: z.number().min(0).max(150).optional(),
})

export const loginValidation = z.object({
    email: z.string().email(),
    password: z.string().min(6),
})

export const updateProfileValidation = z.object({
    firstName: z.string().min(1).optional(),
    lastName: z.string().min(1).optional(),
    age: z.number().min(0).max(150).optional(),
    pfp: z.string().url().nullable().optional(),
    bio: z.string().max(500).nullable().optional(),
    gender: z.string().max(80).nullable().optional(),
    pronouns: z.string().max(80).nullable().optional(),
    wellnessGoal: z.string().max(120).nullable().optional(),
    timezone: z.string().max(80).nullable().optional(),
});


export type UpdateProfileType = z.infer<typeof updateProfileValidation>;
export type RegisterValidType = z.infer<typeof registerValidation>;
export type LoginValidType = z.infer<typeof loginValidation>;
