CREATE TABLE "home_activities" (
    "user_id" uuid PRIMARY KEY REFERENCES "users"("id") ON DELETE cascade,
    "activities" jsonb NOT NULL,
    "revision" integer DEFAULT 1 NOT NULL CHECK ("revision" > 0),
    "updated_at" timestamptz DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "home_commands" (
    "user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE cascade,
    "request_id" uuid NOT NULL,
    "payload_hash" text NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX "home_commands_owner_request_uidx" ON "home_commands" ("user_id", "request_id");
