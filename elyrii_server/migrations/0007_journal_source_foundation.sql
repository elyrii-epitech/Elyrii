CREATE TABLE "context_source_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"source_id" uuid NOT NULL,
	"revision" integer NOT NULL,
	"change" text NOT NULL,
	"generation" integer NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "context_source_event_identity_unique" UNIQUE("user_id","kind","source_id","revision","change"),
	CONSTRAINT "context_source_event_change_check" CHECK ("context_source_events"."change" IN ('created', 'updated', 'deleted', 'excluded')),
	CONSTRAINT "context_source_event_status_check" CHECK ("context_source_events"."status" IN ('pending', 'completed', 'discarded'))
);
--> statement-breakpoint
CREATE TABLE "context_source_versions" (
	"user_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"source_id" uuid NOT NULL,
	"revision" integer NOT NULL,
	"chat_message_id" uuid,
	"journal_entry_id" uuid,
	"source_created_at" timestamp with time zone,
	"active" boolean DEFAULT true NOT NULL,
	"excluded" boolean DEFAULT false NOT NULL,
	CONSTRAINT "context_source_versions_user_id_kind_source_id_revision_pk" PRIMARY KEY("user_id","kind","source_id","revision"),
	CONSTRAINT "context_source_identity_check" CHECK ("context_source_versions"."revision" > 0 AND (
        ("context_source_versions"."kind" = 'chat' AND "context_source_versions"."chat_message_id" = "context_source_versions"."source_id" AND "context_source_versions"."chat_message_id" IS NOT NULL AND "context_source_versions"."journal_entry_id" IS NULL) OR
        ("context_source_versions"."kind" = 'journal' AND "context_source_versions"."journal_entry_id" = "context_source_versions"."source_id" AND "context_source_versions"."journal_entry_id" IS NOT NULL AND "context_source_versions"."chat_message_id" IS NULL)))
);
--> statement-breakpoint
ALTER TABLE "chat_messages" ADD COLUMN "context_revision" integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE "context_extraction_jobs" ADD COLUMN "source_revision" integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE "journal_entries" ADD COLUMN "context_revision" integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE "journal_entries" ADD COLUMN "context_suppressed" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "user_context_facts" ADD COLUMN "source_kind" text;--> statement-breakpoint
ALTER TABLE "user_context_facts" ADD COLUMN "source_id" uuid;--> statement-breakpoint
ALTER TABLE "user_context_facts" ADD COLUMN "source_revision" integer;--> statement-breakpoint
ALTER TABLE "user_memories" ADD COLUMN "source_kind" text;--> statement-breakpoint
ALTER TABLE "user_memories" ADD COLUMN "source_id" uuid;--> statement-breakpoint
ALTER TABLE "user_memories" ADD COLUMN "source_revision" integer;--> statement-breakpoint
ALTER TABLE "journal_entries" ADD CONSTRAINT "journal_entries_owner_id_unique" UNIQUE("user_id","id");--> statement-breakpoint
ALTER TABLE "context_source_events" ADD CONSTRAINT "context_source_events_user_id_kind_source_id_revision_context_source_versions_user_id_kind_source_id_revision_fk" FOREIGN KEY ("user_id","kind","source_id","revision") REFERENCES "public"."context_source_versions"("user_id","kind","source_id","revision") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "context_source_versions" ADD CONSTRAINT "context_source_versions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "context_source_versions" ADD CONSTRAINT "context_source_versions_user_id_chat_message_id_chat_messages_user_id_id_fk" FOREIGN KEY ("user_id","chat_message_id") REFERENCES "public"."chat_messages"("user_id","id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "context_source_versions" ADD CONSTRAINT "context_source_versions_user_id_journal_entry_id_journal_entries_user_id_id_fk" FOREIGN KEY ("user_id","journal_entry_id") REFERENCES "public"."journal_entries"("user_id","id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "context_source_event_pending_idx" ON "context_source_events" USING btree ("created_at") WHERE "context_source_events"."status" = 'pending';--> statement-breakpoint
ALTER TABLE "user_context_facts" ADD CONSTRAINT "user_context_facts_version_fk" FOREIGN KEY ("user_id","source_kind","source_id","source_revision") REFERENCES "public"."context_source_versions"("user_id","kind","source_id","revision") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_memories" ADD CONSTRAINT "user_memories_version_fk" FOREIGN KEY ("user_id","source_kind","source_id","source_revision") REFERENCES "public"."context_source_versions"("user_id","kind","source_id","revision") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
-- Backfill source identities and legacy chat aliases before enforcing provenance.
INSERT INTO context_source_versions (user_id, kind, source_id, revision, chat_message_id, source_created_at, excluded)
SELECT user_id, 'chat', id, context_revision, id, created_at AT TIME ZONE 'UTC', context_suppressed FROM chat_messages;
--> statement-breakpoint
INSERT INTO context_source_versions (user_id, kind, source_id, revision, journal_entry_id, source_created_at, active, excluded)
SELECT user_id, 'journal', id, context_revision, id, created_at AT TIME ZONE 'UTC', deleted_at IS NULL, context_suppressed FROM journal_entries;
--> statement-breakpoint
UPDATE user_context_facts SET source_kind = 'chat', source_id = source_message_id, source_revision = 1 WHERE source_message_id IS NOT NULL;
--> statement-breakpoint
UPDATE user_memories SET source_kind = 'chat', source_id = source_message_id, source_revision = 1 WHERE source_message_id IS NOT NULL;
--> statement-breakpoint
ALTER TABLE "user_context_facts" ADD CONSTRAINT "user_context_facts_provenance_check" CHECK (("user_context_facts"."source_kind" IS NULL AND "user_context_facts"."source_id" IS NULL AND "user_context_facts"."source_revision" IS NULL AND "user_context_facts"."source_message_id" IS NULL) OR
        ("user_context_facts"."source_kind" IS NOT NULL AND "user_context_facts"."source_kind" IN ('chat', 'journal') AND "user_context_facts"."source_id" IS NOT NULL AND "user_context_facts"."source_revision" > 0 AND "user_context_facts"."source_revision" IS NOT NULL
         AND (("user_context_facts"."source_kind" = 'chat' AND "user_context_facts"."source_message_id" IS NOT NULL AND "user_context_facts"."source_message_id" = "user_context_facts"."source_id") OR
              ("user_context_facts"."source_kind" = 'journal' AND "user_context_facts"."source_message_id" IS NULL))));--> statement-breakpoint
ALTER TABLE "user_memories" ADD CONSTRAINT "user_memories_provenance_check" CHECK (("user_memories"."source_kind" IS NULL AND "user_memories"."source_id" IS NULL AND "user_memories"."source_revision" IS NULL AND "user_memories"."source_message_id" IS NULL) OR
        ("user_memories"."source_kind" IS NOT NULL AND "user_memories"."source_kind" IN ('chat', 'journal') AND "user_memories"."source_id" IS NOT NULL AND "user_memories"."source_revision" > 0 AND "user_memories"."source_revision" IS NOT NULL
         AND (("user_memories"."source_kind" = 'chat' AND "user_memories"."source_message_id" IS NOT NULL AND "user_memories"."source_message_id" = "user_memories"."source_id") OR
              ("user_memories"."source_kind" = 'journal' AND "user_memories"."source_message_id" IS NULL))));
--> statement-breakpoint
-- All source mutations, including direct SQL, maintain identities and the outbox atomically.
CREATE FUNCTION context_source_before() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE changed boolean;
BEGIN
    IF TG_OP = 'INSERT' THEN NEW.context_revision := 1; RETURN NEW; END IF;
    IF (NEW.id, NEW.user_id) IS DISTINCT FROM (OLD.id, OLD.user_id) THEN
        RAISE EXCEPTION 'Source ownership and identity are immutable' USING ERRCODE = '23514';
    END IF;
    NEW.context_suppressed := OLD.context_suppressed OR NEW.context_suppressed;
    NEW.context_revision := OLD.context_revision;
    IF TG_TABLE_NAME = 'journal_entries' THEN
        IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            RAISE EXCEPTION 'Journal observation time is immutable' USING ERRCODE = '23514';
        END IF;
        IF OLD.deleted_at IS NOT NULL THEN NEW.deleted_at := OLD.deleted_at; END IF;
        changed := (NEW.title, NEW.content, NEW.mood) IS DISTINCT FROM (OLD.title, OLD.content, OLD.mood);
    ELSE
        changed := (NEW.message, NEW.role, NEW.conversation_id, NEW.created_at) IS DISTINCT FROM (OLD.message, OLD.role, OLD.conversation_id, OLD.created_at);
    END IF;
    IF changed THEN NEW.context_revision := OLD.context_revision + 1; END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER aaa_context_source_before BEFORE INSERT OR UPDATE ON chat_messages FOR EACH ROW EXECUTE FUNCTION context_source_before();
--> statement-breakpoint
CREATE TRIGGER aaa_context_source_before BEFORE INSERT OR UPDATE ON journal_entries FOR EACH ROW EXECUTE FUNCTION context_source_before();
--> statement-breakpoint
CREATE FUNCTION context_source_after() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_kind text; alive boolean := true; event_change text; epoch integer;
BEGIN
    v_kind := CASE WHEN TG_TABLE_NAME = 'chat_messages' THEN 'chat' ELSE 'journal' END;
    IF v_kind = 'journal' THEN alive := NEW.deleted_at IS NULL; END IF;
    SELECT context_generation INTO epoch FROM users WHERE id = NEW.user_id FOR UPDATE;
    IF NOT FOUND THEN RETURN NEW; END IF;
    IF TG_OP = 'INSERT' THEN event_change := 'created';
    ELSE
        IF NEW.context_revision <> OLD.context_revision OR NOT alive THEN
            UPDATE context_source_versions SET active = false WHERE user_id = NEW.user_id AND kind = v_kind AND source_id = NEW.id;
            UPDATE user_context_facts SET status = 'superseded' WHERE user_id = NEW.user_id AND source_kind = v_kind AND source_id = NEW.id AND status = 'active';
            UPDATE user_memories SET status = 'superseded' WHERE user_id = NEW.user_id AND source_kind = v_kind AND source_id = NEW.id AND status = 'active';
            UPDATE context_source_events SET status = 'discarded' WHERE user_id = NEW.user_id AND kind = v_kind AND source_id = NEW.id AND status = 'pending';
            IF v_kind = 'chat' THEN UPDATE context_extraction_jobs SET status = 'discarded' WHERE source_message_id = NEW.id AND status IN ('pending','retry','awaiting'); END IF;
            event_change := CASE WHEN alive THEN 'updated' ELSE 'deleted' END;
        END IF;
        IF NEW.context_suppressed AND NOT OLD.context_suppressed THEN
            UPDATE users SET context_generation = context_generation + 1 WHERE id = NEW.user_id RETURNING context_generation INTO epoch;
            UPDATE context_source_versions SET excluded = true WHERE user_id = NEW.user_id AND kind = v_kind AND source_id = NEW.id;
            UPDATE context_source_events SET status = 'discarded' WHERE user_id = NEW.user_id AND kind = v_kind AND source_id = NEW.id AND status = 'pending';
            event_change := 'excluded';
        END IF;
    END IF;
    INSERT INTO context_source_versions (user_id, kind, source_id, revision, chat_message_id, journal_entry_id, source_created_at, active, excluded)
    VALUES (NEW.user_id, v_kind, NEW.id, NEW.context_revision,
        CASE WHEN v_kind = 'chat' THEN NEW.id END, CASE WHEN v_kind = 'journal' THEN NEW.id END,
        NEW.created_at AT TIME ZONE 'UTC', alive, NEW.context_suppressed)
    ON CONFLICT (user_id, kind, source_id, revision) DO NOTHING;
    IF v_kind = 'journal' AND event_change IS NOT NULL THEN
        INSERT INTO context_source_events (user_id, kind, source_id, revision, change, generation)
        VALUES (NEW.user_id, v_kind, NEW.id, NEW.context_revision, event_change, epoch)
        ON CONFLICT (user_id, kind, source_id, revision, change) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER context_source_after AFTER INSERT OR UPDATE ON chat_messages FOR EACH ROW EXECUTE FUNCTION context_source_after();
--> statement-breakpoint
CREATE TRIGGER context_source_after AFTER INSERT OR UPDATE ON journal_entries FOR EACH ROW EXECUTE FUNCTION context_source_after();
--> statement-breakpoint
-- Compatibility: old writers may still supply only source_message_id. Explicit v2
-- references cannot be retargeted to a new revision by the compatibility adapter.
CREATE FUNCTION validate_context_provenance() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE source context_source_versions%ROWTYPE;
BEGIN
    IF NEW.source_kind IS NULL AND NEW.source_id IS NULL AND NEW.source_revision IS NULL AND NEW.source_message_id IS NOT NULL THEN
        NEW.source_kind := 'chat'; NEW.source_id := NEW.source_message_id;
        SELECT context_revision INTO NEW.source_revision FROM chat_messages WHERE user_id = NEW.user_id AND id = NEW.source_message_id;
    END IF;
    IF NEW.source_kind = 'chat' AND NEW.source_message_id IS NULL THEN NEW.source_message_id := NEW.source_id; END IF;
    IF NEW.source_kind = 'chat' AND NEW.source_message_id IS DISTINCT FROM NEW.source_id THEN
        RAISE EXCEPTION 'Mismatched legacy source alias' USING ERRCODE = '23503';
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF (NEW.source_kind, NEW.source_id, NEW.source_revision) IS NOT DISTINCT FROM (OLD.source_kind, OLD.source_id, OLD.source_revision)
            AND NEW.status <> 'active' THEN RETURN NEW; END IF;
        -- Existing explicit corrections can survive source exclusion, but not edits/deletion.
        IF (NEW.source_kind, NEW.source_id, NEW.source_revision) IS NOT DISTINCT FROM (OLD.source_kind, OLD.source_id, OLD.source_revision)
            AND NEW.status = OLD.status THEN RETURN NEW; END IF;
    END IF;
    IF NEW.source_kind IS NOT NULL THEN
        SELECT * INTO source FROM context_source_versions WHERE user_id = NEW.user_id AND kind = NEW.source_kind
            AND source_id = NEW.source_id AND revision = NEW.source_revision FOR SHARE;
        IF NOT FOUND THEN RAISE EXCEPTION 'Missing or mismatched source revision' USING ERRCODE = '23503'; END IF;
        IF NOT source.active OR source.excluded THEN RAISE EXCEPTION 'Source revision is unavailable' USING ERRCODE = '23514'; END IF;
    END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER validate_context_provenance BEFORE INSERT OR UPDATE ON user_context_facts FOR EACH ROW EXECUTE FUNCTION validate_context_provenance();
--> statement-breakpoint
CREATE TRIGGER validate_context_provenance BEFORE INSERT OR UPDATE ON user_memories FOR EACH ROW EXECUTE FUNCTION validate_context_provenance();
--> statement-breakpoint
CREATE FUNCTION extraction_source_revision() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE current_revision integer;
BEGIN
    SELECT context_revision INTO current_revision FROM chat_messages WHERE user_id = NEW.user_id AND id = NEW.source_message_id;
    IF NEW.source_revision <> current_revision THEN RAISE EXCEPTION 'Stale extraction source' USING ERRCODE = '23514'; END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER extraction_source_revision BEFORE INSERT ON context_extraction_jobs FOR EACH ROW EXECUTE FUNCTION extraction_source_revision();
--> statement-breakpoint
CREATE OR REPLACE FUNCTION context_extraction_forget_barrier() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' OR (NEW.status = 'deleted' AND OLD.status <> 'deleted') THEN
        UPDATE users SET context_generation = context_generation + 1 WHERE id = OLD.user_id;
        UPDATE context_extraction_keys SET suppressed = true WHERE user_id = OLD.user_id AND target_id = OLD.id;
        UPDATE chat_messages SET context_suppressed = true WHERE user_id = OLD.user_id AND id = OLD.source_message_id AND NOT context_suppressed;
        IF OLD.source_kind = 'journal' THEN
            UPDATE journal_entries SET context_suppressed = true WHERE user_id = OLD.user_id AND id = OLD.source_id AND NOT context_suppressed;
        END IF;
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE FUNCTION validate_source_version_identity() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE current_revision integer; owner uuid; source_time timestamptz; excluded boolean; alive boolean;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF (NEW.user_id, NEW.kind, NEW.source_id, NEW.revision, NEW.chat_message_id, NEW.journal_entry_id, NEW.source_created_at)
            IS DISTINCT FROM (OLD.user_id, OLD.kind, OLD.source_id, OLD.revision, OLD.chat_message_id, OLD.journal_entry_id, OLD.source_created_at)
            OR (NOT OLD.active AND NEW.active) OR (OLD.excluded AND NOT NEW.excluded) THEN
            RAISE EXCEPTION 'Source version identities and exclusions are immutable' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
    END IF;
    IF NEW.kind = 'chat' THEN
        SELECT user_id, context_revision, created_at AT TIME ZONE 'UTC', context_suppressed, true INTO owner, current_revision, source_time, excluded, alive FROM chat_messages WHERE id = NEW.source_id;
    ELSE
        SELECT user_id, context_revision, created_at AT TIME ZONE 'UTC', context_suppressed, deleted_at IS NULL INTO owner, current_revision, source_time, excluded, alive FROM journal_entries WHERE id = NEW.source_id;
    END IF;
    IF owner IS DISTINCT FROM NEW.user_id OR current_revision IS DISTINCT FROM NEW.revision OR source_time IS DISTINCT FROM NEW.source_created_at
        OR excluded IS DISTINCT FROM NEW.excluded OR alive IS DISTINCT FROM NEW.active THEN
        RAISE EXCEPTION 'Mismatched source identity or revision' USING ERRCODE = '23503';
    END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER validate_source_version_identity BEFORE INSERT OR UPDATE ON context_source_versions FOR EACH ROW EXECUTE FUNCTION validate_source_version_identity();

--> statement-breakpoint
ALTER TABLE journal_entries ADD CONSTRAINT journal_entries_user_id_users_id_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
--> statement-breakpoint
-- Existing journals get dormant source events; no consumer/recall is enabled by this migration.
INSERT INTO context_source_events (user_id, kind, source_id, revision, change, generation)
SELECT s.user_id, s.kind, s.source_id, s.revision, 'created', u.context_generation
FROM context_source_versions s JOIN users u ON u.id = s.user_id
WHERE s.kind = 'journal' AND s.active AND NOT s.excluded
ON CONFLICT (user_id, kind, source_id, revision, change) DO NOTHING;

--> statement-breakpoint
ALTER TABLE journal_entry_tags DROP CONSTRAINT journal_entry_tags_entry_id_journal_entries_id_fk;
--> statement-breakpoint
ALTER TABLE journal_entry_tags ADD CONSTRAINT journal_entry_tags_entry_id_journal_entries_id_fk FOREIGN KEY (entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE;
--> statement-breakpoint
ALTER TABLE journal_media DROP CONSTRAINT journal_media_entry_id_journal_entries_id_fk;
--> statement-breakpoint
ALTER TABLE journal_media ADD CONSTRAINT journal_media_entry_id_journal_entries_id_fk FOREIGN KEY (entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE;
