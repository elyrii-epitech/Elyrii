\set ON_ERROR_STOP on
-- This fixture runs on schema 0006, then applies 0007 inside the isolated test DB.
INSERT INTO users (id, first_name, last_name, email, password, age) VALUES
('00000000-0000-4000-8000-000000000001', 'Source', 'Upgrade', 'source-upgrade@test.local', 'test', 30);
INSERT INTO chat_messages (id, user_id, role, message, created_at) VALUES
('00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'user', 'Original chat', '2026-01-01 10:00:00.123456');
INSERT INTO user_context_facts (id, user_id, key, kind, value, origin, source_message_id) VALUES
('00000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', 'length', 'preference', '"brief"', 'explicit', '00000000-0000-4000-8000-000000000002');
INSERT INTO user_memories (id, user_id, content, origin, retention, source_message_id) VALUES
('00000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000001', 'Original memory', 'explicit', 'long_term', '00000000-0000-4000-8000-000000000002'),
('00000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000001', 'Manual memory', 'explicit', 'long_term', NULL);
INSERT INTO journal_entries (id, user_id, title, content, created_at) VALUES
('00000000-0000-4000-8000-000000000006', '00000000-0000-4000-8000-000000000001', 'Old journal', 'Original entry', '2025-01-01 10:00:00.123456');
