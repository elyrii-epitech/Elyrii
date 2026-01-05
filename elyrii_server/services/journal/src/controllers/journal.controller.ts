import { createFactory } from "hono/factory";
import JournalRepository from "../repository/journal.repository";
import { sValidator } from "@hono/standard-validator";
import { createEntriySchema, updateEntrySchema } from "../utils/journal.zod";

class JournalController {
    private readonly factory = createFactory();
    private readonly journalRepository: JournalRepository = new JournalRepository();
    
    readonly getEntries = this.factory.createHandlers(async (ctx) => {
        const entries = await this.journalRepository.getEntries();
        return ctx.json(entries); 
    });

    readonly getEntryById = this.factory.createHandlers(async (ctx) => { 
        const entryId = ctx.req.param("entryId");
        if (!entryId) {
            return ctx.json({ error: "Entry ID is required" }, 400);
        }
        try {
            const entry = await this.journalRepository.getEntryById(entryId);
            return ctx.json(entry); 
        } catch (error) {
            return ctx.json({ error: "Entry not found" }, 404);
        }
    });

    readonly createEntry = this.factory.createHandlers(sValidator("json", createEntriySchema), async (ctx) => {
        const body = ctx.req.valid("json");
        if (!body) {
            return ctx.json({ error: "Invalid request body" }, 400);
        }
        try {
            const entry = await this.journalRepository.createEntry(body);
            return ctx.json({ message: "Entry created successfully", body: entry }, 201);
        } catch (error) {
            return ctx.json({ error: "Failed to create entry" }, 500);
        }
    });

    readonly updateEntry = this.factory.createHandlers(sValidator("json", updateEntrySchema), async (ctx) => {
        const body = ctx.req.valid("json");
        const entryId = ctx.req.param("entryId");

        if (!body || !entryId) {
            return ctx.json({ error: "Invalid request body" }, 400);
        }

        try {
            const entry = await this.journalRepository.updateEntry(entryId, body);
            return ctx.json({ message: "Entry updated successfully", body: entry }, 200);
        } catch (error) {
            return ctx.json({ error: "Failed to update entry" }, 500);
        }
    });

    readonly deleteEntry = this.factory.createHandlers(async (ctx) => { 
        return ctx.json({ message: "Delete entry" }); 
    });
}

export default JournalController;
