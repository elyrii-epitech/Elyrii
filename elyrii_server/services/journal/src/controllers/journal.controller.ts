import { createFactory } from "hono/factory";

class JournalController {
    private readonly factory = createFactory();
    
    readonly getEntries = this.factory.createHandlers(async (ctx) => { 
        return ctx.json({ message: "Get entries" }); 
    });

    readonly getEntryById = this.factory.createHandlers(async (ctx) => { 
        return ctx.json({ message: "Get entry by ID" }); 
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
