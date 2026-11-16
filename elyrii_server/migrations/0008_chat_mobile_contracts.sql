-- Nullable for existing history. New replies retain their source and are duplicate safe.
ALTER TABLE "chat_messages" ADD COLUMN "reply_to_id" uuid;
--> statement-breakpoint
CREATE UNIQUE INDEX "chat_messages_reply_to_unique" ON "chat_messages" ("reply_to_id");
--> statement-breakpoint
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_reply_source_fk"
    FOREIGN KEY ("user_id", "conversation_id", "reply_to_id")
    REFERENCES "chat_messages" ("user_id", "conversation_id", "id") ON DELETE CASCADE;
--> statement-breakpoint
CREATE INDEX "chat_messages_mobile_page_idx" ON "chat_messages"
    ("user_id", "conversation_id", date_trunc('milliseconds', "created_at"), "id");
--> statement-breakpoint
CREATE TABLE "deleted_chat_conversations" (
    "user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
    "conversation_id" text NOT NULL,
    "deleted_at" timestamp DEFAULT now() NOT NULL,
    CONSTRAINT "deleted_chat_conversations_owner_unique" UNIQUE("user_id", "conversation_id")
);
