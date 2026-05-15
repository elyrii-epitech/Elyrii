# Elyrii Server API Documentation

Welcome to the Elyrii Monolithic Server API documentation. This documentation is consolidated from all system modules and auto-generated using TypeDoc.

## Modules

The Elyrii server is organized into five core modules:

### 🔐 [Auth](./api/modules/auth.html)
Handles user authentication, registration, and session management using JWT.

### 💬 [Chat](./api/modules/chat.html)
Manages real-time messaging, WebSocket connections, and Kafka integration for AI message processing.

### 📔 [Journal](./api/modules/journal.html)
Handles personal journaling, including creation, retrieval, multimedia support, and tagging.

### ⚔️ [Quest](./api/modules/quest.html)
Manages gamified challenges, AI-proposed quests, and progress tracking.

### 👤 [User](./api/modules/user.html)
Handles user profile management and data retrieval.

## Quick Start

### Installation
```bash
# Install root dependencies
bun install
```

### Running the Server
```bash
# Development mode
bun run dev

# Production mode
bun run prod
```

### Generating Documentation
```bash
# Run the documentation build script
bun run docs:build
```

## API Overview

The monolithic server exposes a unified API on port 3000 (default):

- **Auth**: `/auth/*`
- **Chat**: `/chat/*`
- **Journal**: `/journal/*`
- **Quest**: `/challenge/*`
- **User**: `/user/*`
- **Swagger UI**: `/swagger`
- **OpenAPI Spec**: `/openapi.json`

## Documentation Structure

```
docs/
├── index.md                # This file
├── index.html              # Documentation landing page
└── api/                    # Main API documentation (generated)
    ├── modules/            # Individual module documentation
    └── classes/            # Repository and controller classes
```

## Contributing

When adding new features or modifying existing code, please ensure to:

1. Add JSDoc comments to your functions, classes, and interfaces.
2. Run `bun run docs:build` to regenerate documentation.
3. Verify changes in the local documentation server (`bun run docs:serve`).

## License

[Your License Here]
