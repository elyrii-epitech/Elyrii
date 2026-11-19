CREATE EXTENSION IF NOT EXISTS vector;--> statement-breakpoint
CREATE TYPE "public"."context_fact_kind" AS ENUM('fact', 'preference');--> statement-breakpoint
CREATE TYPE "public"."context_origin" AS ENUM('explicit', 'inferred');--> statement-breakpoint
CREATE TYPE "public"."context_status" AS ENUM('active', 'superseded', 'deleted');--> statement-breakpoint
CREATE TYPE "public"."memory_retention" AS ENUM('short_term', 'long_term');--> statement-breakpoint
CREATE TABLE "conversation_summaries" (
	"user_id" uuid NOT NULL,
	"conversation_id" text NOT NULL,
	"summary" text NOT NULL,
	"through_message_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "conversation_summaries_user_id_conversation_id_pk" PRIMARY KEY("user_id","conversation_id"),
	CONSTRAINT "conversation_summaries_content_check" CHECK (length(btrim("conversation_summaries"."summary")) > 0)
);
--> statement-breakpoint
CREATE TABLE "memory_embeddings" (
	"memory_id" uuid NOT NULL,
	"model" text NOT NULL,
	"dimensions" integer NOT NULL,
	"embedding" vector NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "memory_embeddings_memory_id_model_pk" PRIMARY KEY("memory_id","model"),
	CONSTRAINT "memory_embeddings_model_check" CHECK (length(btrim("memory_embeddings"."model")) > 0),
	CONSTRAINT "memory_embeddings_dimensions_check" CHECK ("memory_embeddings"."dimensions" > 0 AND vector_dims("memory_embeddings"."embedding") = "memory_embeddings"."dimensions")
);
--> statement-breakpoint
CREATE TABLE "user_context_facts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"key" text NOT NULL,
	"kind" "context_fact_kind" NOT NULL,
	"value" jsonb NOT NULL,
	"origin" "context_origin" NOT NULL,
	"source_message_id" uuid,
	"status" "context_status" DEFAULT 'active' NOT NULL,
	"valid_from" timestamp with time zone DEFAULT now() NOT NULL,
	"valid_until" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_context_facts_key_check" CHECK (length(btrim("user_context_facts"."key")) > 0),
	CONSTRAINT "user_context_facts_validity_check" CHECK ("user_context_facts"."valid_until" IS NULL OR "user_context_facts"."valid_until" > "user_context_facts"."valid_from")
);
--> statement-breakpoint
CREATE TABLE "user_memories" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"content" text NOT NULL,
	"origin" "context_origin" NOT NULL,
	"source_message_id" uuid,
	"retention" "memory_retention" NOT NULL,
	"status" "context_status" DEFAULT 'active' NOT NULL,
	"event_at" timestamp with time zone,
	"valid_from" timestamp with time zone DEFAULT now() NOT NULL,
	"valid_until" timestamp with time zone,
	"expires_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_memories_content_check" CHECK (length(btrim("user_memories"."content")) > 0),
	CONSTRAINT "user_memories_short_term_expiry_check" CHECK ("user_memories"."retention" <> 'short_term' OR "user_memories"."expires_at" IS NOT NULL),
	CONSTRAINT "user_memories_expiry_check" CHECK ("user_memories"."expires_at" IS NULL OR "user_memories"."expires_at" > "user_memories"."created_at"),
	CONSTRAINT "user_memories_validity_check" CHECK ("user_memories"."valid_until" IS NULL OR "user_memories"."valid_until" > "user_memories"."valid_from")
);
--> statement-breakpoint
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_user_id_id_unique" UNIQUE("user_id","id");--> statement-breakpoint
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_user_conversation_id_unique" UNIQUE("user_id","conversation_id","id");--> statement-breakpoint
ALTER TABLE "conversation_summaries" ADD CONSTRAINT "conversation_summaries_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "conversation_summaries" ADD CONSTRAINT "conversation_summaries_through_message_fk" FOREIGN KEY ("user_id","conversation_id","through_message_id") REFERENCES "public"."chat_messages"("user_id","conversation_id","id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "memory_embeddings" ADD CONSTRAINT "memory_embeddings_memory_id_user_memories_id_fk" FOREIGN KEY ("memory_id") REFERENCES "public"."user_memories"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_context_facts" ADD CONSTRAINT "user_context_facts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_context_facts" ADD CONSTRAINT "user_context_facts_source_fk" FOREIGN KEY ("user_id","source_message_id") REFERENCES "public"."chat_messages"("user_id","id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_memories" ADD CONSTRAINT "user_memories_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_memories" ADD CONSTRAINT "user_memories_source_fk" FOREIGN KEY ("user_id","source_message_id") REFERENCES "public"."chat_messages"("user_id","id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "user_context_facts_active_key_uidx" ON "user_context_facts" USING btree ("user_id","key") WHERE "user_context_facts"."status" = 'active';--> statement-breakpoint
CREATE INDEX "user_context_facts_user_status_idx" ON "user_context_facts" USING btree ("user_id","status");--> statement-breakpoint
CREATE INDEX "user_context_facts_source_idx" ON "user_context_facts" USING btree ("user_id","source_message_id");--> statement-breakpoint
CREATE INDEX "user_memories_user_status_retention_idx" ON "user_memories" USING btree ("user_id","status","retention");--> statement-breakpoint
CREATE INDEX "user_memories_expiry_idx" ON "user_memories" USING btree ("expires_at") WHERE "user_memories"."expires_at" IS NOT NULL;--> statement-breakpoint
CREATE INDEX "user_memories_source_idx" ON "user_memories" USING btree ("user_id","source_message_id");--> statement-breakpoint
CREATE INDEX "chat_messages_context_history_idx" ON "chat_messages" USING btree ("user_id","conversation_id","created_at");
