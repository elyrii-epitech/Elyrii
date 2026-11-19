import { z } from "zod";
import { ContextLifecycleRepository } from "../../repository/context-lifecycle.repository";

/** Fixed-delay scheduling prevents overlap. Multiple processes may safely run it. */
export function startContextCleanup(repository = new ContextLifecycleRepository()) {
    const interval = z.coerce.number().int().min(1000).max(86400000).parse(process.env.CONTEXT_CLEANUP_INTERVAL_MS ?? 60000);
    const batch = z.coerce.number().int().min(1).max(500).parse(process.env.CONTEXT_CLEANUP_BATCH_SIZE ?? 100);
    let stopped = false, timer: ReturnType<typeof setTimeout> | undefined;
    const run = async () => {
        try { await repository.cleanup(batch); }
        catch { console.error("[Context] Expiry cleanup failed; retrying on next interval"); }
        if (!stopped) { timer = setTimeout(run, interval); timer.unref(); }
    };
    void run();
    return () => { stopped = true; clearTimeout(timer); };
}
