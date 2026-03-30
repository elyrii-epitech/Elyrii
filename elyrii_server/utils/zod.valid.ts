import z from "zod";

export const registerValidation = z.object({
    email: z.email(),
    password: z.string().min(6),
    lastName: z.string().min(1),
    firstName: z.string().min(1),
    age: z.number().min(0).max(150).optional(),
})

export const loginValidation = z.object({
    email: z.email(),
    password: z.string().min(6),
})

export type RegisterValidType = z.infer<typeof registerValidation>;
export type LoginValidType = z.infer<typeof loginValidation>;
