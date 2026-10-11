-- Apply through the deployment migration process before releasing the client.
-- Existing NULL request IDs remain valid; retries with a UUID cannot duplicate.
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS client_request_id uuid;
CREATE UNIQUE INDEX IF NOT EXISTS journal_entries_user_request_idx
  ON journal_entries(user_id, client_request_id);
CREATE TABLE IF NOT EXISTS ai_content_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message_id uuid NOT NULL, conversation_id text NOT NULL,
  reason text NOT NULL, content text NOT NULL,
  status text NOT NULL DEFAULT 'OPEN', created_at timestamp NOT NULL DEFAULT now(), reviewed_at timestamp
);
CREATE INDEX IF NOT EXISTS ai_reports_queue_idx ON ai_content_reports(status, created_at);
CREATE INDEX IF NOT EXISTS ai_reports_user_idx ON ai_content_reports(user_id);
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE, expires_at timestamp NOT NULL, created_at timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS journal_entries_page_idx ON journal_entries(user_id, date_trunc('milliseconds', created_at), id);
