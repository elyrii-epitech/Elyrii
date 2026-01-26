import { createFactory } from "hono/factory";
import JournalRepository from "../repository/journal.repository";
import { sValidator } from "@hono/standard-validator";
import { createEntriySchema, updateEntrySchema } from "../utils/journal.zod";
import type { HonoEnv } from "../utils/hono.types";

class JournalController {
    private readonly factory = createFactory<HonoEnv>();
    private readonly journalRepository: JournalRepository = new JournalRepository();
    
    public readonly getEntries = this.factory.createHandlers(async (ctx) => {
        const userID = ctx.get("user").userId;
        const startDateParam = ctx.req.query("startDate");
        const endDateParam = ctx.req.query("endDate");

        let startDate: Date | undefined;
        let endDate: Date | undefined;

        if (startDateParam) {
            startDate = new Date(startDateParam);
            if (isNaN(startDate.getTime())) {
                return ctx.json({ error: "Invalid startDate format" }, 400);
            }
        }

        if (endDateParam) {
            endDate = new Date(endDateParam);
            if (isNaN(endDate.getTime())) {
                return ctx.json({ error: "Invalid endDate format" }, 400);
            }
        }

        const entries = await this.journalRepository.getEntries(userID, startDate, endDate);
        return ctx.json(entries); 
    });
    
    public readonly getUserEntries = this.factory.createHandlers(async (ctx) => {
        const userID = ctx.get("user").userId;
        const entries = await this.journalRepository.getEntries(userID);
        return ctx.json(entries); 
    });
    
    public readonly getEntryById = this.factory.createHandlers(async (ctx) => { 
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

    public readonly createEntry = this.factory.createHandlers(sValidator("json", createEntriySchema), async (ctx) => {
        const body = ctx.req.valid("json");
        const userID = ctx.get("user").userId;

        if (!body) {
            return ctx.json({ error: "Invalid request body" }, 400);
        }
        try {
            body["userId"] = userID;
            const entry = await this.journalRepository.createEntry(body);
            return ctx.json({ message: "Entry created successfully", body: entry }, 201);
        } catch (error) {
            return ctx.json({ error: "Failed to create entry" }, 500);
        }
    });

    public readonly updateEntry = this.factory.createHandlers(sValidator("json", updateEntrySchema), async (ctx) => {
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

    public readonly deleteEntry = this.factory.createHandlers(async (ctx) => { 
        const entryId = ctx.req.param("entryId");
        if (!entryId) {
            return ctx.json({ error: "Entry ID is required" }, 400);
        }
        try {
            await this.journalRepository.softDeleteEntry(entryId);
            return ctx.json({ message: "Entry soft-deleted successfully" }, 200);
        } catch (error) {
            return ctx.json({ error: "Failed to soft-delete entry" }, 500);
        }
    });
}

export default JournalController;
