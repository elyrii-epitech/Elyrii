import { db } from "../config/db.config";
import { journalEntriesTable, type JournalEntry, type NewJournalEntry } from "../config/db/journal.table";
import { eq } from "drizzle-orm";

class JournalRepository {
    // TODO: Implement repository methods
    // Example methods:
    // async getEntries(userId: string): Promise<any[]> { }
    // async getEntryById(id: string): Promise<any | null> { }
    // async createEntry(data: any): Promise<any> { }
    // async updateEntry(id: string, data: any): Promise<any> { }
    // async deleteEntry(id: string): Promise<boolean> { }
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
        return { ...data, updatedAt: new Date() } as JournalEntry;
    }
    async deleteEntry(_id: string): Promise<boolean> {
        return true;
    }
}

export default JournalRepository;