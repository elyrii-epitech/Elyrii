CREATE TABLE "coach_journeys" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    "user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE cascade,
    "path" jsonb NOT NULL,
    "status" text DEFAULT 'active' NOT NULL CHECK ("status" IN ('active', 'paused', 'completed')),
    "completed_step_count" integer DEFAULT 0 NOT NULL CHECK ("completed_step_count" >= 0),
    "revision" integer DEFAULT 1 NOT NULL CHECK ("revision" > 0),
    "is_current" boolean DEFAULT true NOT NULL,
    "started_at" timestamptz NOT NULL,
    "updated_at" timestamptz NOT NULL,
    "completed_at" timestamptz,
    CONSTRAINT "coach_journeys_progress_check" CHECK (
        jsonb_array_length("path"->'steps') > 0 AND
        "completed_step_count" <= jsonb_array_length("path"->'steps') AND
        ("status" = 'completed') = ("completed_step_count" = jsonb_array_length("path"->'steps')) AND
        ("status" = 'completed') = ("completed_at" IS NOT NULL) AND
        "updated_at" >= "started_at" AND
        ("completed_at" IS NULL OR ("completed_at" >= "started_at" AND "completed_at" <= "updated_at"))
    )
);
--> statement-breakpoint
CREATE UNIQUE INDEX "coach_journeys_current_user_idx" ON "coach_journeys" ("user_id") WHERE "is_current";
--> statement-breakpoint
CREATE INDEX "coach_journeys_user_idx" ON "coach_journeys" ("user_id");
