import { createFactory } from "hono/factory";
import JournalRepository from "../repository/journal.repository";

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

    readonly createEntry = this.factory.createHandlers(async (ctx) => { 
        return ctx.json({ message: "Create entry" }); 
    });

    readonly updateEntry = this.factory.createHandlers(async (ctx) => { 
        return ctx.json({ message: "Update entry" }); 
    });

    readonly deleteEntry = this.factory.createHandlers(async (ctx) => { 
        return ctx.json({ message: "Delete entry" }); 
    });
}

export default JournalController;
