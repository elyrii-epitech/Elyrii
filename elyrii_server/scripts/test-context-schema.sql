\set ON_ERROR_STOP on
BEGIN;

CREATE FUNCTION pg_temp.expect_error(statement text, expected_state text) RETURNS void AS $$
BEGIN
BEGIN
EXECUTE statement;
EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = expected_state THEN RETURN; END IF;
        RAISE;
END;
    RAISE EXCEPTION 'Statement unexpectedly succeeded: %', statement;
END;
$$ LANGUAGE plpgsql;

INSERT INTO users (id, first_name, last_name, email, password, age) VALUES
                                                                        ('00000000-0000-0000-0000-000000000001', 'One', 'Test', 'one@example.test', 'test', 25),
                                                                        ('00000000-0000-0000-0000-000000000002', 'Two', 'Test', 'two@example.test', 'test', 25);
INSERT INTO chat_messages (id, user_id, conversation_id, role, message) VALUES
                                                                            ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'default', 'user', 'I graduated'),
                                                                            ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'default', 'user', 'I feel sad');

INSERT INTO user_context_facts (user_id, key, kind, value, origin, source_message_id) VALUES
    ('00000000-0000-0000-0000-000000000001', 'response_style', 'preference', '"brief"', 'explicit', '10000000-0000-0000-0000-000000000001');
SELECT pg_temp.expect_error($q$
                                INSERT INTO user_context_facts (user_id, key, kind, value, origin) VALUES
    ('00000000-0000-0000-0000-000000000001', 'response_style', 'preference', '"long"', 'explicit')
$q$, '23505');
UPDATE user_context_facts SET status = 'superseded';
INSERT INTO user_context_facts (user_id, key, kind, value, origin) VALUES
    ('00000000-0000-0000-0000-000000000001', 'response_style', 'preference', '"long"', 'explicit');
SELECT pg_temp.expect_error($q$
                                INSERT INTO user_context_facts (user_id, key, kind, value, origin, source_message_id) VALUES
    ('00000000-0000-0000-0000-000000000002', 'foreign', 'fact', 'true', 'inferred', '10000000-0000-0000-0000-000000000001')
$q$, '23503');

INSERT INTO conversation_summaries (user_id, conversation_id, summary, through_message_id) VALUES
    ('00000000-0000-0000-0000-000000000001', 'default', 'Graduated', '10000000-0000-0000-0000-000000000001');
SELECT pg_temp.expect_error($q$
                                INSERT INTO conversation_summaries (user_id, conversation_id, summary, through_message_id) VALUES
    ('00000000-0000-0000-0000-000000000001', 'different', 'Invalid', '10000000-0000-0000-0000-000000000001')
$q$, '23503');
SELECT pg_temp.expect_error($q$
                                INSERT INTO conversation_summaries (user_id, conversation_id, summary, through_message_id) VALUES
    ('00000000-0000-0000-0000-000000000002', 'default', 'Invalid', '10000000-0000-0000-0000-000000000001')
$q$, '23503');

INSERT INTO user_memories (id, user_id, content, origin, source_message_id, retention, event_at) VALUES
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Graduated', 'explicit', '10000000-0000-0000-0000-000000000001', 'long_term', now() - interval '1 year');
INSERT INTO user_memories (user_id, content, origin, retention, valid_until, expires_at) VALUES
    ('00000000-0000-0000-0000-000000000002', 'Sad today', 'explicit', 'short_term', now() + interval '1 day', now() + interval '2 days');
SELECT pg_temp.expect_error($q$
                                INSERT INTO user_memories (user_id, content, origin, retention) VALUES
    ('00000000-0000-0000-0000-000000000001', 'Temporary', 'explicit', 'short_term')
$q$, '23514');
SELECT pg_temp.expect_error($q$
                                UPDATE user_memories SET expires_at = created_at - interval '1 second'
$q$, '23514');
SELECT pg_temp.expect_error($q$
                                UPDATE user_memories SET valid_until = valid_from - interval '1 second'
$q$, '23514');
SELECT pg_temp.expect_error($q$
                                UPDATE user_memories SET source_message_id = '10000000-0000-0000-0000-000000000002'
    WHERE id = '20000000-0000-0000-0000-000000000001'
$q$, '23503');

INSERT INTO memory_embeddings (memory_id, model, dimensions, embedding) VALUES
    ('20000000-0000-0000-0000-000000000001', 'test-v1', 3, '[1,2,3]');
SELECT pg_temp.expect_error($q$
                                INSERT INTO memory_embeddings (memory_id, model, dimensions, embedding) VALUES
    ('20000000-0000-0000-0000-000000000001', 'test-v2', 4, '[1,2,3]')
$q$, '23514');

DELETE FROM chat_messages WHERE id = '10000000-0000-0000-0000-000000000001';
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM user_memories WHERE user_id = '00000000-0000-0000-0000-000000000001')
       OR EXISTS (SELECT 1 FROM memory_embeddings)
       OR EXISTS (SELECT 1 FROM conversation_summaries)
       OR EXISTS (SELECT 1 FROM user_context_facts WHERE source_message_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Source deletion did not cascade';
END IF;
END $$;

DELETE FROM users WHERE id IN ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM user_memories) OR EXISTS (SELECT 1 FROM user_context_facts) THEN
        RAISE EXCEPTION 'User deletion did not cascade';
END IF;
END $$;
ROLLBACK;