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

The project uses **Drizzle ORM** with checked-in PostgreSQL migrations:

```bash
bun run db:migrate
```

Containers use PostgreSQL 16 with pgvector and apply migrations before starting
the server. For existing databases previously created with `db:push`, follow the
[database upgrade guide](../docs/server/database.md) before starting the new stack.
The guide also describes the three context layers and database-only setup.


## Deployment

The server is Docker-ready. Use Docker Compose to spin up the entire environment (Server, Redpanda, Postgres):

```bash
docker compose up
```

## License

[Your License Here]
