import { describe, expect, test } from "bun:test";
import { updateMascotValidation } from "./mascot.validation";

describe("mascot studio persistence", () => {
    test("retains independent colors, finish and a four-slot outfit", () => {
        const customization = { colors: { body: "#B8A3DC", details: "#FFFFFF", ears: "#F2CE94", eyes: "#3B3549", accessories: "#91C5BD" }, finish: "satin" as const };
        const equippedCosmetics = ["beret", "round_glasses", "cozy_scarf", "mini_backpack"];
        const parsed = updateMascotValidation.parse({ appearance: "nature", personality: { tone: "calm", customization }, equippedCosmetics });
        expect(parsed.personality?.customization).toEqual(customization);
        expect(parsed.equippedCosmetics).toEqual(equippedCosmetics);
        expect(parsed.personality?.tone).toBe("calm");
    });
    test("legacy theme and wardrobe updates remain valid", () => {
        expect(updateMascotValidation.safeParse({ appearance: "cosmic", personality: { equippedCosmetics: ["beret"] } }).success).toBe(true);
    });
    test("rejects malformed colors and unsupported finishes", () => {
        for (const body of ["red", "#FFF", "#GG0000", 123, null]) {
            expect(updateMascotValidation.safeParse({ personality: { customization: { colors: { body } } } }).success).toBe(false);
        }
        expect(updateMascotValidation.safeParse({ personality: { customization: { finish: "unknown" } } }).success).toBe(false);
        expect(updateMascotValidation.safeParse({ personality: { customization: { colors: { ears: "pink" } } } }).success).toBe(false);
    });
});
