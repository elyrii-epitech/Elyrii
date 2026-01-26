import { db } from "../config/db.config";
import { journalEntriesTable, type JournalEntry, type NewJournalEntry } from "../config/db/journal.table";
import { eq, and, gte, lte, isNull } from "drizzle-orm";

class JournalRepository {
    async getEntries(
        userId?: string,
        startDate?: Date,
        endDate?: Date
    ): Promise<JournalEntry[]> {
        const conditions = [isNull(journalEntriesTable.deletedAt)];

        if (userId) {
            conditions.push(eq(journalEntriesTable.userId, userId));
        }
        if (startDate) {
            conditions.push(gte(journalEntriesTable.createdAt, startDate));
        }
        if (endDate) {
            conditions.push(lte(journalEntriesTable.createdAt, endDate));
        }

        const entries = await db.select().from(journalEntriesTable).where(and(...conditions));
        return entries || [];
    }

    public async getEntryById(_id: string): Promise<JournalEntry | null> {
        const [entry] = await db.select().from(journalEntriesTable).where(eq(journalEntriesTable.id, _id)).limit(1);
        return entry || null;
    }

    public async createEntry(data: NewJournalEntry): Promise<JournalEntry> {
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
        return await db.transaction(async (tx) => {
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
            if (data.deletedAt !== undefined && data.deletedAt !== existing.deletedAt)
                updatePayload.deletedAt = data.deletedAt;

            if (Object.keys(updatePayload).length === 1 && data.deletedAt === undefined) {
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
    
    async softDeleteEntry(_id: string): Promise<boolean> {
        return await db.transaction(async (tx) => {
            const [updated] = await tx.update(journalEntriesTable)
                .set({ deletedAt: new Date() })
                .where(eq(journalEntriesTable.id, _id))
                .returning({ id: journalEntriesTable.id });
            
            if (!updated) {
                tx.rollback();
                throw new Error('Failed to soft delete journal entry');
            }
            return true;
        });
    }
}

export default JournalRepository;