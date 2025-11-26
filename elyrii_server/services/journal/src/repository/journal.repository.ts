import { db } from "../config/db.config";
import { journalEntriesTable, type JournalEntry, type NewJournalEntry } from "../config/db/journal.table";
import { eq } from "drizzle-orm";

class JournalRepository {
    // TODO: Implement repository methods
    async getEntries(): Promise<JournalEntry[]> {
        const entries = await db.select().from(journalEntriesTable);
        return entries || [];
    }

    async getEntryById(_id: string): Promise<JournalEntry | null> {
        const [entry] = await db.select().from(journalEntriesTable).where(eq(journalEntriesTable.id, _id)).limit(1);
        return entry || null;
    }

    async createEntry(data: NewJournalEntry): Promise<JournalEntry> {
        if (!data.userId || !data.title) {
            throw new Error('User ID and title are required');
        }

        const entry = await db.transaction(async (tx) => {
            const result = await tx.insert(journalEntriesTable).values(data).returning({
                id: journalEntriesTable.id,
                userId: journalEntriesTable.userId,
                title: journalEntriesTable.title,
                createdAt: journalEntriesTable.createdAt,
                updatedAt: journalEntriesTable.updatedAt
            });
            if (!result || result.length === 0) {
                tx.rollback();
                throw new Error('Failed to create journal entry');
            }
            return result[0];
        });

        if (!entry) {
            throw new Error('Failed to create journal entry');
        }
        return { ...entry, id: entry.id, createdAt: entry.createdAt ?? new Date() } as JournalEntry;
    }

    async updateEntry(_id: string, data: Partial<JournalEntry>): Promise<JournalEntry> {
        return db.transaction(async (tx) => {
            const [existing] = await tx.select().from(journalEntriesTable)
                .where(eq(journalEntriesTable.id, _id))
                .limit(1);
            
            if (!existing) {
                tx.rollback();
                throw new Error('Journal entry not found');
            }

            const updatePayload: Partial<JournalEntry> = {};
            if (data.title !== undefined && data.title !== existing.title) 
                updatePayload.title = data.title;
            if (data.content !== undefined && data.content !== existing.content) 
                updatePayload.content = data.content;
            if (data.mood !== undefined && data.mood !== existing.mood) 
                updatePayload.mood = data.mood;

            if (Object.keys(updatePayload).length === 1) {
                return existing as JournalEntry;
            }

            const [updated] = await tx.update(journalEntriesTable)
                .set(updatePayload)
                .where(eq(journalEntriesTable.id, _id))
                .returning();
            
            if (!updated) {
                tx.rollback();
                throw new Error('Failed to update journal entry');
            }
            
            return updated as JournalEntry;
        });
    }
    
    async deleteEntry(_id: string): Promise<boolean> {
        return true;
    }
}

export default JournalRepository;