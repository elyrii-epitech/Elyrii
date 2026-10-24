CREATE TABLE "journal_extraction_jobs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"event_id" uuid NOT NULL,
	"extractor_version" text DEFAULT 'journal-v1' NOT NULL,
	"timezone" text,
	"status" text DEFAULT 'pending' NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"next_attempt_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_error" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"completed_at" timestamp with time zone,
	CONSTRAINT "journal_extraction_event_version_unique" UNIQUE("event_id","extractor_version"),
	CONSTRAINT "journal_extraction_status_check" CHECK ("journal_extraction_jobs"."status" IN ('pending','retry','awaiting','completed','failed','discarded')),
	CONSTRAINT "journal_extraction_attempts_check" CHECK ("journal_extraction_jobs"."attempts" BETWEEN 0 AND 5)
);
--> statement-breakpoint
ALTER TABLE "user_context_facts" ADD COLUMN "evidence" jsonb;--> statement-breakpoint
ALTER TABLE "user_memories" ADD COLUMN "evidence" jsonb;--> statement-breakpoint
ALTER TABLE "journal_extraction_jobs" ADD CONSTRAINT "journal_extraction_jobs_event_id_context_source_events_id_fk" FOREIGN KEY ("event_id") REFERENCES "public"."context_source_events"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "journal_extraction_due_idx" ON "journal_extraction_jobs" USING btree ("next_attempt_at") WHERE "journal_extraction_jobs"."status" IN ('pending','retry','awaiting');