// Only the disposable connected runner calls this. No vector extension is
// installed system-wide; omit vector-only DDL, retain actual context provenance,
// outbox, summary and suppression migrations used by the chat repository.
if (Bun.env.DB_NAME !== "elyrii_frontend_test" || Bun.env.NODE_ENV !== "test") throw new Error("Disposable fixture required");
const output = Bun.argv[2]!;
const schema = (await Bun.file("migrations/0001_three_context_storage.sql").text())
    .split("--> statement-breakpoint")
    .filter(statement => !statement.includes("CREATE EXTENSION") && !statement.includes('"memory_embeddings"'))
    .join("\n");
await Bun.write(output, schema);
