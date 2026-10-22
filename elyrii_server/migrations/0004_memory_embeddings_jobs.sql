CREATE TABLE "embedding_backfills" (
	"model" text PRIMARY KEY NOT NULL,
	"after_id" uuid,
	"rebuild" boolean DEFAULT false NOT NULL,
	"done" boolean DEFAULT false NOT NULL
);
--> statement-breakpoint
CREATE TABLE "memory_embedding_jobs" (
	"memory_id" uuid NOT NULL,
	"model" text NOT NULL,
	"user_id" uuid NOT NULL,
	"content_revision" integer NOT NULL,
	"job_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"next_attempt_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_error" text,
	CONSTRAINT "memory_embedding_jobs_memory_id_model_pk" PRIMARY KEY("memory_id","model"),
	CONSTRAINT "memory_embedding_jobs_status_check" CHECK ("memory_embedding_jobs"."status" IN ('pending','retry','awaiting','completed','failed','discarded')),
	CONSTRAINT "memory_embedding_jobs_attempts_check" CHECK ("memory_embedding_jobs"."attempts" BETWEEN 0 AND 5)
);
--> statement-breakpoint
CREATE TABLE "embedding_models" (
	"id" text PRIMARY KEY NOT NULL,
	"provider_model" text NOT NULL,
	"digest" text NOT NULL,
	"dimensions" integer NOT NULL,
	"metric" text NOT NULL,
	"preprocessing" text NOT NULL,
	"enabled" boolean DEFAULT true NOT NULL,
	CONSTRAINT "embedding_models_dimensions_check" CHECK ("embedding_models"."dimensions" > 0 AND "embedding_models"."dimensions" <= 16000)
);
--> statement-breakpoint
ALTER TABLE "memory_embeddings" ADD COLUMN "content_revision" integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE "user_memories" ADD COLUMN "content_revision" integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE "embedding_backfills" ADD CONSTRAINT "embedding_backfills_model_embedding_models_id_fk" FOREIGN KEY ("model") REFERENCES "public"."embedding_models"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "memory_embedding_jobs" ADD CONSTRAINT "memory_embedding_jobs_memory_id_user_memories_id_fk" FOREIGN KEY ("memory_id") REFERENCES "public"."user_memories"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "memory_embedding_jobs" ADD CONSTRAINT "memory_embedding_jobs_model_embedding_models_id_fk" FOREIGN KEY ("model") REFERENCES "public"."embedding_models"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "memory_embedding_jobs" ADD CONSTRAINT "memory_embedding_jobs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "memory_embedding_jobs_due_idx" ON "memory_embedding_jobs" USING btree ("next_attempt_at") WHERE "memory_embedding_jobs"."status" IN ('pending','retry','awaiting');
--> statement-breakpoint
-- Vectors are a rebuildable cache; old rows have no provable content revision.
DELETE FROM memory_embeddings;
--> statement-breakpoint
CREATE FUNCTION immutable_embedding_model() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF (NEW.id, NEW.provider_model, NEW.digest, NEW.dimensions, NEW.metric, NEW.preprocessing)
       IS DISTINCT FROM (OLD.id, OLD.provider_model, OLD.digest, OLD.dimensions, OLD.metric, OLD.preprocessing) THEN
        RAISE EXCEPTION 'Embedding model versions are immutable' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER immutable_embedding_model BEFORE UPDATE ON embedding_models
FOR EACH ROW EXECUTE FUNCTION immutable_embedding_model();
--> statement-breakpoint
CREATE FUNCTION memory_content_revision() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.content_revision := OLD.content_revision;
    IF (NEW.content, NEW.user_id) IS DISTINCT FROM (OLD.content, OLD.user_id) THEN
        NEW.content_revision := OLD.content_revision + 1;
    END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER memory_content_revision BEFORE UPDATE ON user_memories
FOR EACH ROW EXECUTE FUNCTION memory_content_revision();
--> statement-breakpoint
CREATE FUNCTION refresh_memory_embedding_jobs() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF (NEW.content_revision, NEW.status, NEW.valid_from, NEW.valid_until, NEW.expires_at)
           IS NOT DISTINCT FROM (OLD.content_revision, OLD.status, OLD.valid_from, OLD.valid_until, OLD.expires_at) THEN
            RETURN NEW;
        END IF;
        DELETE FROM memory_embeddings WHERE memory_id = NEW.id;
        UPDATE memory_embedding_jobs SET status = 'discarded' WHERE memory_id = NEW.id;
    END IF;
    -- Serialize registration with memory writes: a new-model backfill must not
    -- miss a memory committed after its cursor passes while registration is pending.
    LOCK TABLE embedding_models IN SHARE MODE;
    IF NEW.status = 'active' AND (NEW.expires_at IS NULL OR NEW.expires_at > greatest(now(), NEW.valid_from))
       AND (NEW.valid_until IS NULL OR NEW.valid_until > greatest(now(), NEW.valid_from)) THEN
        INSERT INTO memory_embedding_jobs (memory_id, model, user_id, content_revision, next_attempt_at)
        SELECT NEW.id, id, NEW.user_id, NEW.content_revision, greatest(now(), NEW.valid_from)
        FROM embedding_models WHERE enabled
        ON CONFLICT (memory_id, model) DO UPDATE SET user_id = NEW.user_id, content_revision = NEW.content_revision,
            job_id = gen_random_uuid(), status = 'pending', attempts = 0, last_error = NULL,
            next_attempt_at = greatest(now(), NEW.valid_from);
    END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER refresh_memory_embedding_jobs AFTER INSERT OR UPDATE ON user_memories
FOR EACH ROW EXECUTE FUNCTION refresh_memory_embedding_jobs();
--> statement-breakpoint
CREATE FUNCTION validate_memory_embedding_revision() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE parent user_memories%ROWTYPE; spec embedding_models%ROWTYPE;
BEGIN
    SELECT * INTO parent FROM user_memories WHERE id = NEW.memory_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Missing memory' USING ERRCODE = '23503'; END IF;
    IF parent.content_revision <> NEW.content_revision OR parent.status <> 'active'
       OR parent.expires_at <= now() OR parent.valid_until <= now() THEN
        RAISE EXCEPTION 'Ineligible or stale memory embedding' USING ERRCODE = '23514';
    END IF;
    SELECT * INTO spec FROM embedding_models WHERE id = NEW.model;
    IF FOUND AND (NOT spec.enabled OR NEW.dimensions <> spec.dimensions OR abs(vector_norm(NEW.embedding) - 1) > 0.001) THEN
        RAISE EXCEPTION 'Embedding model metadata or normalization mismatch' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;
--> statement-breakpoint
CREATE TRIGGER validate_memory_embedding_revision BEFORE INSERT OR UPDATE ON memory_embeddings
FOR EACH ROW EXECUTE FUNCTION validate_memory_embedding_revision();
