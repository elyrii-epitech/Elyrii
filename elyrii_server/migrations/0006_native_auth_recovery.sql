CREATE TABLE "password_reset_tokens" (
    "user_id" uuid PRIMARY KEY NOT NULL REFERENCES "users"("id") ON DELETE cascade,
    "token_hash" text NOT NULL UNIQUE,
    "expires_at" timestamp NOT NULL,
    "created_at" timestamp DEFAULT now() NOT NULL
);
