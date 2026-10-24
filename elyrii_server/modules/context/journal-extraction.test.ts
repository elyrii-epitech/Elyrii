import { expect, test } from "bun:test";
import { journalInputSchema, journalOutputSchema, journalEventDate, supportedJournalProposal, eligibleJournalProposal } from "./journal-extraction.contracts";
import fixtures from "../../../elyrii_ai/test/fixtures/journal_extraction_v1.json";
test("English/French wire fixtures preserve evidence and eligibility", () => {
    for (const fixture of fixtures) {
        const input = journalInputSchema.parse(fixture.input);
        const output = journalOutputSchema.parse(fixture.output);
        for (const p of output.candidates) { expect(supportedJournalProposal(p, input)).toBe(true); expect(eligibleJournalProposal(p)).toBe(true); }
    }
});
test("relative dates use original local calendar day and retain ambiguity", () => {
    const at = "2026-10-20T23:30:00Z";
    expect(journalEventDate("yesterday", at, "Europe/Paris")).toBe("2026-10-20");
    expect(journalEventDate("hier", at, "America/New_York")).toBe("2026-10-19");
    expect(journalEventDate("today", at, null)).toBeNull();
    expect(journalEventDate("Monday", at, "Europe/Paris")).toBeNull();
    expect(journalEventDate("2026-02-30", at, "Europe/Paris")).toBeNull();
    expect(journalEventDate("2026-02-28", at, null)).toBe("2026-02-28");
    expect(journalEventDate("hier", "2026-03-29T01:30:00Z", "Europe/Paris")).toBe("2026-03-28");
});
