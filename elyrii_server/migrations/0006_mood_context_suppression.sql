ALTER TABLE "mood_logs" ADD COLUMN "context_suppressed" boolean DEFAULT false NOT NULL;--> statement-breakpoint
-- Forgetting excludes retained tracker history from context permanently.
CREATE TRIGGER preserve_mood_context_suppression BEFORE UPDATE ON mood_logs
FOR EACH ROW EXECUTE FUNCTION preserve_context_suppression();
