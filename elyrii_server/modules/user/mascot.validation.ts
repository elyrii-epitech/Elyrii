import { z } from "zod";

export const updateMascotValidation = z.object({
    appearance: z.string().min(1).max(50).optional(),
    themeId: z.string().min(1).max(50).optional(),
    equippedCosmetics: z.array(z.string().min(1).max(80)).max(20).optional(),
    personality: z.object({
        tone: z.enum(["supportive", "neutral", "energetic", "calm"]).optional(),
        energy: z.enum(["low", "balanced", "high"]).optional(),
        humor: z.enum(["none", "light", "playful"]).optional(),
        themeId: z.string().min(1).max(50).optional(),
        equippedCosmetics: z.array(z.string().min(1).max(80)).max(20).optional(),
        customization: z.object({
            colors: z.object({
                body: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
                details: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
                ears: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
                eyes: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
                accessories: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
            }).optional(),
            finish: z.enum(["velours", "satin", "porcelain"]).optional(),
        }).optional(),
    }).partial().optional(),
});
