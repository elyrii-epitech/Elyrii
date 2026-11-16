-- Keep existing entries intact; NULL request IDs remain valid for legacy clients.
ALTER TABLE "journal_entries" ADD COLUMN "client_request_id" uuid;
--> statement-breakpoint
CREATE UNIQUE INDEX "journal_entries_user_request_idx"
    ON "journal_entries" ("user_id", "client_request_id");
--> statement-breakpoint
-- JavaScript/Dart cursors round-trip timestamps to milliseconds, so use the
-- same expression for the index, comparison and ordering.
CREATE INDEX "journal_entries_page_idx"
    ON "journal_entries" ("user_id", date_trunc('milliseconds', "created_at"), "id");
