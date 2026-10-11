import { pgTable, uuid, text, timestamp, index } from 'drizzle-orm/pg-core';
import { userTable } from './user.table';
export const aiReportsTable = pgTable('ai_content_reports', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').notNull().references(() => userTable.id, { onDelete: 'cascade' }),
  messageId: uuid('message_id').notNull(),
  conversationId: text('conversation_id').notNull(),
  reason: text('reason').notNull(),
  content: text('content').notNull(),
  status: text('status').notNull().default('OPEN'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  reviewedAt: timestamp('reviewed_at'),
}, (table) => [index('ai_reports_queue_idx').on(table.status, table.createdAt), index('ai_reports_user_idx').on(table.userId)]);
export const passwordResetTable = pgTable('password_reset_tokens', {
  userId: uuid('user_id').primaryKey().references(() => userTable.id, { onDelete: 'cascade' }),
  tokenHash: text('token_hash').notNull().unique(),
  expiresAt: timestamp('expires_at').notNull(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
});
