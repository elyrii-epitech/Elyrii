ALTER TABLE "chat_messages" ADD COLUMN "context_suppressed" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "context_extraction_keys" ADD COLUMN "suppressed" boolean DEFAULT false NOT NULL;--> statement-breakpoint
-- Suppression is a durable privacy decision, not a transient extraction status.
CREATE FUNCTION preserve_context_suppression() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.context_suppressed THEN NEW.context_suppressed := true; END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER preserve_context_suppression BEFORE UPDATE ON chat_messages
FOR EACH ROW EXECUTE FUNCTION preserve_context_suppression();
--> statement-breakpoint
CREATE OR REPLACE FUNCTION context_extraction_forget_barrier() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' OR (NEW.status = 'deleted' AND OLD.status <> 'deleted') THEN
        UPDATE users SET context_generation = context_generation + 1 WHERE id = OLD.user_id;
        UPDATE context_extraction_keys SET suppressed = true WHERE user_id = OLD.user_id AND target_id = OLD.id;
        UPDATE chat_messages SET context_suppressed = true WHERE user_id = OLD.user_id AND id = OLD.source_message_id AND NOT context_suppressed;
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;
