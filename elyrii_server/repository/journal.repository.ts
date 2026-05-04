import { db } from "../config/db.config";
import {
    journalEntriesTable,
    journalEntryTagsTable,
    journalMediaTable,
    journalTagsTable,
    type JournalEntry,
    type JournalMedia,
    type JournalTag,
    type NewJournalEntry,
} from "../config/db/journal.table";
import { eq, and, gte, lte, isNull } from "drizzle-orm";

class JournalRepository {
    private normalizeTagName(name: string): string {
        return name.trim().toLowerCase();
    }

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

    public async getEntryByIdForUser(_id: string, userId: string): Promise<JournalEntry | null> {
        const [entry] = await db
            .select()
            .from(journalEntriesTable)
            .where(and(
                eq(journalEntriesTable.id, _id),
                eq(journalEntriesTable.userId, userId),
                isNull(journalEntriesTable.deletedAt),
            ))
            .limit(1);
        return entry || null;
    }

    public async createEntry(data: NewJournalEntry): Promise<JournalEntry> {
        if (!data.userId || !data.title) {
            throw new Error('User ID and title are required');
        }

        const entry = await db.transaction(async (tx) => {
            const result = await tx.insert(journalEntriesTable).values(data).returning();
            if (!result || result.length === 0) {
                tx.rollback();
                throw new Error('Failed to create journal entry');
            }
            const created = result[0];
            if (!created) {
                tx.rollback();
                throw new Error('Failed to create journal entry');
            }
            return created;
        });

        if (!entry) {
            throw new Error('Failed to create journal entry');
        }
        return { ...entry, id: entry.id, createdAt: entry.createdAt ?? new Date() } as JournalEntry;
    }

    public async createEntryWithRelations(data: NewJournalEntry & { tags?: string[] | null }): Promise<JournalEntry> {
        if (!data.userId || !data.title) {
            throw new Error('User ID and title are required');
        }

        const entry = await db.transaction(async (tx) => {
            const result = await tx.insert(journalEntriesTable).values({
                userId: data.userId,
                title: data.title,
                content: data.content,
                mood: data.mood,
            }).returning();
            if (!result || result.length === 0) {
                tx.rollback();
                throw new Error('Failed to create journal entry');
            }

            const createdEntry = result[0];
            if (!createdEntry) {
                tx.rollback();
                throw new Error('Failed to create journal entry');
            }
            if (data.tags && data.tags.length > 0) {
                await this.setEntryTagsForUser(createdEntry.id, data.userId, data.tags, tx);
            }

            return createdEntry;
        });

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

    async updateEntryForUser(_id: string, userId: string, data: Partial<JournalEntry>): Promise<JournalEntry> {
        return await db.transaction(async (tx) => {
            const [existing] = await tx
                .select()
                .from(journalEntriesTable)
                .where(and(
                    eq(journalEntriesTable.id, _id),
                    eq(journalEntriesTable.userId, userId),
                    isNull(journalEntriesTable.deletedAt),
                ))
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

            if (Object.keys(updatePayload).length === 0) {
                return existing as JournalEntry;
            }

            const [updated] = await tx
                .update(journalEntriesTable)
                .set(updatePayload)
                .where(and(
                    eq(journalEntriesTable.id, _id),
                    eq(journalEntriesTable.userId, userId),
                ))
                .returning();

            if (!updated) {
                tx.rollback();
                throw new Error('Failed to update journal entry');
            }

            return updated as JournalEntry;
        });
    }

    async updateEntryWithRelationsForUser(
        _id: string,
        userId: string,
        data: Partial<JournalEntry>,
        tags?: string[] | null,
    ): Promise<JournalEntry> {
        return await db.transaction(async (tx) => {
            const [existing] = await tx
                .select()
                .from(journalEntriesTable)
                .where(and(
                    eq(journalEntriesTable.id, _id),
                    eq(journalEntriesTable.userId, userId),
                    isNull(journalEntriesTable.deletedAt),
                ))
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

            if (tags !== undefined) {
                await this.setEntryTagsForUser(_id, userId, tags, tx);
            }

            if (Object.keys(updatePayload).length === 0) {
                return existing as JournalEntry;
            }

            const [updated] = await tx
                .update(journalEntriesTable)
                .set(updatePayload)
                .where(and(
                    eq(journalEntriesTable.id, _id),
                    eq(journalEntriesTable.userId, userId),
                ))
                .returning();

            if (!updated) {
                tx.rollback();
                throw new Error('Failed to update journal entry');
            }

            return updated as JournalEntry;
        });
    }

    async setEntryTagsForUser(
        entryId: string,
        userId: string,
        tags: string[] | null,
        tx: any = db,
    ): Promise<void> {
        const [entry] = await tx
            .select({ id: journalEntriesTable.id })
            .from(journalEntriesTable)
            .where(and(
                eq(journalEntriesTable.id, entryId),
                eq(journalEntriesTable.userId, userId),
                isNull(journalEntriesTable.deletedAt),
            ))
            .limit(1);

        if (!entry) {
            throw new Error("Journal entry not found");
        }

        await tx.delete(journalEntryTagsTable).where(eq(journalEntryTagsTable.entryId, entryId));

        if (!tags || tags.length === 0) {
            return;
        }

        for (const tagNameRaw of tags) {
            const tagName = this.normalizeTagName(tagNameRaw);
            if (!tagName) continue;

            let [tag] = await tx
                .select()
                .from(journalTagsTable)
                .where(and(
                    eq(journalTagsTable.userId, userId),
                    eq(journalTagsTable.name, tagName),
                ))
                .limit(1);

            if (!tag) {
                const createdTags = await tx
                    .insert(journalTagsTable)
                    .values({ userId, name: tagName })
                    .returning();
                tag = createdTags[0];
            }

            if (!tag) continue;

            await tx.insert(journalEntryTagsTable).values({
                entryId,
                tagId: tag.id,
            });
        }
    }

    async getTagsForUser(userId: string): Promise<JournalTag[]> {
        return db
            .select()
            .from(journalTagsTable)
            .where(eq(journalTagsTable.userId, userId));
    }

    async createTagForUser(userId: string, name: string): Promise<JournalTag> {
        const normalized = this.normalizeTagName(name);
        if (!normalized) {
            throw new Error("Tag name is required");
        }

        const [existing] = await db
            .select()
            .from(journalTagsTable)
            .where(and(
                eq(journalTagsTable.userId, userId),
                eq(journalTagsTable.name, normalized),
            ))
            .limit(1);

        if (existing) return existing;

        const [created] = await db
            .insert(journalTagsTable)
            .values({ userId, name: normalized })
            .returning();

        if (!created) {
            throw new Error("Failed to create tag");
        }
        return created;
    }

    async updateTagForUser(tagId: string, userId: string, name: string): Promise<JournalTag> {
        const normalized = this.normalizeTagName(name);
        if (!normalized) {
            throw new Error("Tag name is required");
        }

        const [updated] = await db
            .update(journalTagsTable)
            .set({ name: normalized })
            .where(and(
                eq(journalTagsTable.id, tagId),
                eq(journalTagsTable.userId, userId),
            ))
            .returning();

        if (!updated) {
            throw new Error("Tag not found");
        }
        return updated;
    }

    async deleteTagForUser(tagId: string, userId: string): Promise<void> {
        const [tag] = await db
            .select({ id: journalTagsTable.id })
            .from(journalTagsTable)
            .where(and(
                eq(journalTagsTable.id, tagId),
                eq(journalTagsTable.userId, userId),
            ))
            .limit(1);

        if (!tag) {
            throw new Error("Tag not found");
        }

        await db.delete(journalEntryTagsTable).where(eq(journalEntryTagsTable.tagId, tagId));
        await db.delete(journalTagsTable).where(eq(journalTagsTable.id, tagId));
    }

    async addMediaForEntry(entryId: string, userId: string, url: string, type?: string): Promise<JournalMedia> {
        const [entry] = await db
            .select({ id: journalEntriesTable.id })
            .from(journalEntriesTable)
            .where(and(
                eq(journalEntriesTable.id, entryId),
                eq(journalEntriesTable.userId, userId),
                isNull(journalEntriesTable.deletedAt),
            ))
            .limit(1);

        if (!entry) {
            throw new Error("Journal entry not found");
        }

        const [created] = await db
            .insert(journalMediaTable)
            .values({ entryId, url, type: type ?? null })
            .returning();

        if (!created) {
            throw new Error("Failed to add media");
        }
        return created;
    }

    async listMediaForEntry(entryId: string, userId: string): Promise<JournalMedia[]> {
        const [entry] = await db
            .select({ id: journalEntriesTable.id })
            .from(journalEntriesTable)
            .where(and(
                eq(journalEntriesTable.id, entryId),
                eq(journalEntriesTable.userId, userId),
                isNull(journalEntriesTable.deletedAt),
            ))
            .limit(1);

        if (!entry) {
            throw new Error("Journal entry not found");
        }

        return db
            .select()
            .from(journalMediaTable)
            .where(eq(journalMediaTable.entryId, entryId));
    }

    async deleteMediaForEntry(entryId: string, userId: string, mediaId: string): Promise<void> {
        const [entry] = await db
            .select({ id: journalEntriesTable.id })
            .from(journalEntriesTable)
            .where(and(
                eq(journalEntriesTable.id, entryId),
                eq(journalEntriesTable.userId, userId),
                isNull(journalEntriesTable.deletedAt),
            ))
            .limit(1);

        if (!entry) {
            throw new Error("Journal entry not found");
        }

        const [deleted] = await db
            .delete(journalMediaTable)
            .where(and(
                eq(journalMediaTable.id, mediaId),
                eq(journalMediaTable.entryId, entryId),
            ))
            .returning();

        if (!deleted) {
            throw new Error("Media not found");
        }
    }
    
    async softDeleteEntry(_id: string): Promise<boolean> {
        return await db.transaction(async (tx) => {
            const [updated] = await tx.update(journalEntriesTable)
                .set({ deletedAt: new Date() })
                .where(eq(journalEntriesTable.id, _id))
                .returning();
            
            if (!updated) {
                tx.rollback();
                throw new Error('Failed to soft delete journal entry');
            }
            return true;
        });
    }

    async softDeleteEntryForUser(_id: string, userId: string): Promise<boolean> {
        return await db.transaction(async (tx) => {
            const [updated] = await tx
                .update(journalEntriesTable)
                .set({ deletedAt: new Date() })
                .where(and(
                    eq(journalEntriesTable.id, _id),
                    eq(journalEntriesTable.userId, userId),
                    isNull(journalEntriesTable.deletedAt),
                ))
                .returning();

            if (!updated) {
                tx.rollback();
                throw new Error('Failed to soft delete journal entry');
            }
            return true;
        });
    }
}

export default JournalRepository;
