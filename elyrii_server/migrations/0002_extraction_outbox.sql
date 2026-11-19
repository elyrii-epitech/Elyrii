CREATE TABLE "context_extraction_jobs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"sequence" bigserial NOT NULL,
	"user_id" uuid NOT NULL,
	"conversation_id" text NOT NULL,
	"source_message_id" uuid NOT NULL,
	"request_id" uuid NOT NULL,
	"extractor_version" text DEFAULT 'v1' NOT NULL,
	"generation" integer NOT NULL,
	"timezone" text NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"next_attempt_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_error" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"completed_at" timestamp with time zone,
	CONSTRAINT "context_extraction_source_version_unique" UNIQUE("source_message_id","extractor_version"),
	CONSTRAINT "context_extraction_status_check" CHECK ("context_extraction_jobs"."status" IN ('pending', 'retry', 'awaiting', 'completed', 'failed', 'discarded')),
	CONSTRAINT "context_extraction_attempts_check" CHECK ("context_extraction_jobs"."attempts" BETWEEN 0 AND 5)
);
--> statement-breakpoint
CREATE TABLE "context_extraction_keys" (
	"user_id" uuid NOT NULL,
	"key" text NOT NULL,
	"sequence" bigint NOT NULL,
	"target_id" uuid NOT NULL,
	CONSTRAINT "context_extraction_keys_user_id_key_pk" PRIMARY KEY("user_id","key")
);
--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "context_generation" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "context_extraction_jobs" ADD CONSTRAINT "context_extraction_jobs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "context_extraction_jobs" ADD CONSTRAINT "context_extraction_jobs_user_id_conversation_id_source_message_id_chat_messages_user_id_conversation_id_id_fk" FOREIGN KEY ("user_id","conversation_id","source_message_id") REFERENCES "public"."chat_messages"("user_id","conversation_id","id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "context_extraction_keys" ADD CONSTRAINT "context_extraction_keys_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "context_extraction_due_idx" ON "context_extraction_jobs" USING btree ("next_attempt_at") WHERE "context_extraction_jobs"."status" IN ('pending', 'retry', 'awaiting');
--> statement-breakpoint
-- Direct deletes and soft deletes fence all previously queued extraction.
-- New messages snapshot the new generation under a user lock.
CREATE FUNCTION context_extraction_forget_barrier() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE users SET context_generation = context_generation + 1 WHERE id = OLD.user_id;
        RETURN OLD;
    END IF;
    IF NEW.status = 'deleted' AND OLD.status <> 'deleted' THEN
        UPDATE users SET context_generation = context_generation + 1 WHERE id = OLD.user_id;
    END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER context_facts_forget_barrier BEFORE DELETE OR UPDATE OF status ON user_context_facts
FOR EACH ROW EXECUTE FUNCTION context_extraction_forget_barrier();
--> statement-breakpoint
CREATE TRIGGER context_memories_forget_barrier BEFORE DELETE OR UPDATE OF status ON user_memories
FOR EACH ROW EXECUTE FUNCTION context_extraction_forget_barrier();
