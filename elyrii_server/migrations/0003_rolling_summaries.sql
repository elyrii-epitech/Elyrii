CREATE TABLE "conversation_summary_tasks" (
	"user_id" uuid NOT NULL,
	"conversation_id" text NOT NULL,
	"revision" integer DEFAULT 0 NOT NULL,
	"history_version" integer DEFAULT 0 NOT NULL,
	"dirty" boolean DEFAULT true NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"job_id" uuid,
	"source_ids" jsonb,
	"snapshot_through_at" timestamp,
	"snapshot_through_id" uuid,
	"model" text,
	"policy" jsonb,
	"attempts" integer DEFAULT 0 NOT NULL,
	"next_attempt_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_error" text,
	CONSTRAINT "conversation_summary_tasks_user_id_conversation_id_pk" PRIMARY KEY("user_id","conversation_id"),
	CONSTRAINT "conversation_summary_tasks_status_check" CHECK ("conversation_summary_tasks"."status" IN ('pending','retry','awaiting','idle','failed')),
	CONSTRAINT "conversation_summary_tasks_attempts_check" CHECK ("conversation_summary_tasks"."attempts" BETWEEN 0 AND 5)
);
--> statement-breakpoint
ALTER TABLE "conversation_summary_tasks" ADD CONSTRAINT "conversation_summary_tasks_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "conversation_summary_tasks_due_idx" ON "conversation_summary_tasks" USING btree ("next_attempt_at") WHERE "conversation_summary_tasks"."status" IN ('pending','retry','awaiting');
--> statement-breakpoint
-- Existing conversations are eligible for background catch-up after deployment.
INSERT INTO conversation_summary_tasks (user_id, conversation_id)
SELECT DISTINCT user_id, conversation_id FROM chat_messages;
--> statement-breakpoint
CREATE FUNCTION invalidate_conversation_summary(owner_id uuid, conversation text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = owner_id) THEN RETURN; END IF;
    INSERT INTO conversation_summary_tasks (user_id, conversation_id) VALUES (owner_id, conversation)
    ON CONFLICT (user_id, conversation_id) DO NOTHING;
    -- Lock before deleting the summary; result writers take this same lock.
    PERFORM 1 FROM conversation_summary_tasks WHERE user_id = owner_id AND conversation_id = conversation FOR UPDATE;
    DELETE FROM conversation_summaries WHERE user_id = owner_id AND conversation_id = conversation;
    UPDATE conversation_summary_tasks SET revision = revision + 1, history_version = history_version + 1, dirty = true, status = 'pending',
        job_id = NULL, source_ids = NULL, snapshot_through_at = NULL, snapshot_through_id = NULL,
        attempts = 0, next_attempt_at = now(), last_error = NULL
    WHERE user_id = owner_id AND conversation_id = conversation;
END;
$$;
--> statement-breakpoint
CREATE FUNCTION track_conversation_summary_sources() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE boundary_at timestamp; boundary_id uuid; task conversation_summary_tasks%ROWTYPE;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM invalidate_conversation_summary(OLD.user_id, OLD.conversation_id);
        IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
        IF NEW.user_id = OLD.user_id AND NEW.conversation_id = OLD.conversation_id THEN RETURN NEW; END IF;
        PERFORM invalidate_conversation_summary(NEW.user_id, NEW.conversation_id);
        RETURN NEW;
    END IF;
    INSERT INTO conversation_summary_tasks (user_id, conversation_id) VALUES (NEW.user_id, NEW.conversation_id)
    ON CONFLICT (user_id, conversation_id) DO UPDATE SET dirty = true, history_version = conversation_summary_tasks.history_version + 1,
        status = CASE WHEN conversation_summary_tasks.status = 'idle' THEN 'pending' ELSE conversation_summary_tasks.status END;
    SELECT * INTO task FROM conversation_summary_tasks WHERE user_id = NEW.user_id AND conversation_id = NEW.conversation_id;
    SELECT m.created_at, m.id INTO boundary_at, boundary_id FROM conversation_summaries s
        JOIN chat_messages m ON m.id = s.through_message_id AND m.user_id = s.user_id AND m.conversation_id = s.conversation_id
        WHERE s.user_id = NEW.user_id AND s.conversation_id = NEW.conversation_id;
    IF (NEW.created_at, NEW.id) <= (boundary_at, boundary_id)
        OR (NEW.created_at, NEW.id) <= (task.snapshot_through_at, task.snapshot_through_id) THEN
        PERFORM invalidate_conversation_summary(NEW.user_id, NEW.conversation_id);
    END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER conversation_summary_sources_changed AFTER INSERT OR UPDATE OR DELETE ON chat_messages
FOR EACH ROW EXECUTE FUNCTION track_conversation_summary_sources();
--> statement-breakpoint
CREATE FUNCTION fence_deleted_summary() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE source_exists boolean;
BEGIN
    -- A boundary FK cascade can run after the source-change trigger. Preserve
    -- rebuild scheduling regardless of trigger order; direct forgetting stays idle.
    SELECT EXISTS (SELECT 1 FROM chat_messages WHERE id = OLD.through_message_id
        AND user_id = OLD.user_id AND conversation_id = OLD.conversation_id) INTO source_exists;
    UPDATE conversation_summary_tasks SET revision = revision + 1,
        status = CASE WHEN source_exists THEN 'idle' ELSE 'pending' END, dirty = NOT source_exists,
        job_id = NULL, source_ids = NULL, snapshot_through_at = NULL, snapshot_through_id = NULL,
        attempts = 0, next_attempt_at = now()
    WHERE user_id = OLD.user_id AND conversation_id = OLD.conversation_id;
    RETURN OLD;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER conversation_summary_deleted AFTER DELETE ON conversation_summaries
FOR EACH ROW EXECUTE FUNCTION fence_deleted_summary();
