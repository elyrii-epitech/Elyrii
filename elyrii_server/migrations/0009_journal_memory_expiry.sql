-- Expiry cleanup identifies a single journal memory in its transaction. Ordinary
-- deletes and explicit forgetting retain the source-wide suppression barrier.
CREATE OR REPLACE FUNCTION context_extraction_forget_barrier() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE expiring_journal_memory boolean := false;
BEGIN
    IF TG_OP = 'DELETE' AND TG_TABLE_NAME = 'user_memories' THEN
        expiring_journal_memory := OLD.source_kind = 'journal'
            AND OLD.id::text = current_setting('elyrii.expiring_journal_memory_id', true);
    END IF;
    IF TG_OP = 'DELETE' OR (NEW.status = 'deleted' AND OLD.status <> 'deleted') THEN
        UPDATE users SET context_generation = context_generation + 1 WHERE id = OLD.user_id;
        UPDATE context_extraction_keys SET suppressed = true WHERE user_id = OLD.user_id AND target_id = OLD.id;
        UPDATE chat_messages SET context_suppressed = true WHERE user_id = OLD.user_id AND id = OLD.source_message_id AND NOT context_suppressed;
        IF OLD.source_kind = 'journal' AND NOT coalesce(expiring_journal_memory, false) THEN
            UPDATE journal_entries SET context_suppressed = true WHERE user_id = OLD.user_id AND id = OLD.source_id AND NOT context_suppressed;
        END IF;
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;
