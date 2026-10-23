# Elyrii Server Documentation

This repository contains the Elyrii monolithic server, consolidating multiple services into a single, maintainable application.

## Architecture

The server is built using **Hono** and **Bun**, organized into modular components:

- **Auth**: Handles user authentication, registration, and session management (JWT).
- **Chat**: Real-time messaging with WebSocket support and Kafka integration.
- **Journal**: Personal journaling with multimedia support and tagging.
- **Quest**: Gamified challenges and AI-proposed tasks.
- **User**: Profile management and user-related operations.

## Documentation

For local mobile testing, native session renewal, and production VPS mail
configuration, see [Mobile/backend connection](../docs/server/mobile-connection.md).
`bun run test:mobile` runs the connected HTTP contract suite against a disposable
local `elyrii_frontend_test` database.

### Generating Documentation

Documentation is auto-generated using **TypeDoc**. To generate the complete API reference:

```bash
# Install dependencies
bun install

# Generate documentation
bun run docs:build
```

The documentation will be generated in `docs/api/`.

### Viewing Documentation

After generation, you can serve the documentation locally:

```bash
# Start documentation server
bun run docs:serve
```

Then open http://localhost:8080 in your browser.

## Project Structure

```
elyrii_server/
├── config/             # Shared configurations (DB, Kafka)
├── middleware/         # Shared middlewares (Auth, etc.)
├── modules/            # Core business logic modules
│   ├── auth/
│   ├── chat/
│   ├── journal/
│   ├── quest/
│   └── user/
├── repository/         # Data access layer
├── utils/              # Shared utility functions
├── docs/               # Generated and static documentation
├── scripts/            # Utility scripts (docs generation, etc.)
└── package.json        # Main configuration
```

## Development

To start the development server with hot-reload:

```bash
bun run dev
```

### Database Management

The project uses **Drizzle ORM**. To push schema changes to the database:

```bash
bun run db:push
```

## Deployment

The server is Docker-ready. Use Docker Compose to spin up the entire environment (Server, Redpanda, Postgres):

```bash
docker compose up
```

## License

[Your License Here]
