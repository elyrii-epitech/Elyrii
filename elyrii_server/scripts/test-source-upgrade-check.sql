\set ON_ERROR_STOP on
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_context_facts WHERE id = '00000000-0000-4000-8000-000000000003'
        AND source_kind = 'chat' AND source_id = source_message_id AND source_revision = 1 AND value = '"brief"' AND status = 'active') THEN
        RAISE EXCEPTION 'Chat fact provenance changed during migration'; END IF;
    IF NOT EXISTS (SELECT 1 FROM user_memories WHERE id = '00000000-0000-4000-8000-000000000004'
        AND source_kind = 'chat' AND source_id = source_message_id AND source_revision = 1 AND content = 'Original memory' AND status = 'active') THEN
        RAISE EXCEPTION 'Chat memory provenance changed during migration'; END IF;
    IF NOT EXISTS (SELECT 1 FROM user_memories WHERE id = '00000000-0000-4000-8000-000000000005' AND source_kind IS NULL AND source_id IS NULL) THEN
        RAISE EXCEPTION 'Manual provenance changed during migration'; END IF;
    IF NOT EXISTS (SELECT 1 FROM context_source_versions WHERE kind = 'journal' AND source_id = '00000000-0000-4000-8000-000000000006'
        AND source_created_at = '2025-01-01 10:00:00.123456+00'::timestamptz AND active) THEN
        RAISE EXCEPTION 'Journal observation time lost precision'; END IF;
    IF (SELECT count(*) FROM context_source_events WHERE source_id = '00000000-0000-4000-8000-000000000006') <> 1 THEN
        RAISE EXCEPTION 'Missing or duplicated dormant journal event'; END IF;
END $$;
DELETE FROM chat_messages WHERE id = '00000000-0000-4000-8000-000000000002';
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM user_context_facts WHERE source_message_id IS NOT NULL) OR EXISTS (SELECT 1 FROM user_memories WHERE source_message_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Legacy source cascade changed'; END IF;
END $$;
