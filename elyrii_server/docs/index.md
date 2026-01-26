# Elyrii Server API Documentation

Welcome to the Elyrii Server API documentation. This documentation is auto-generated from the TypeScript source code using TypeDoc.

## Services

The Elyrii server consists of three microservices:

### 📦 [Auth Service](./api/auth/README.md)
Handles user authentication, authorization, and session management. Provides secure endpoints for login, registration, and token validation.

### 💬 [Chat Service](./api/chat/README.md)
Manages real-time messaging, chat rooms, and message history. Includes WebSocket support for live communications and Kafka integration for message processing.

### 🌐 [Gateway Service](./api/gateway/README.md)
API gateway that routes requests to appropriate microservices. Handles request validation, rate limiting, and response aggregation.

### 📔 [Journal Service](./api/journal/README.md)
Handles personal journaling, including creating, retrieving, updating, and deleting journal entries.

### ⚔️ [Quest Service](./api/quest/README.md)
Manages gamified challenges (quests), including progress tracking, AI proposals, and completion logic.

## Quick Start

### Installation
```bash
# Install dependencies
bun install
```

### Running Services
```bash
# Run individual services
cd services/auth && bun run dev
cd services/chat && bun run dev
cd services/gateway && bun run dev
cd services/journal && bun run start:dev
cd services/quest && bun run start:dev

# Or use Docker
docker-compose up
```

### Generating Documentation
```bash
# Generate all documentation
bun run docs

# Generate individual service docs
bun run docs:auth
bun run docs:chat
bun run docs:gateway
bun run docs:journal
bun run docs:quest
```

## API Overview

Each service exposes its own API endpoints:

- **Auth Service**: Port 3001 - `/auth/*`
- **Chat Service**: Port 3002 - `/chat/*`
- **Journal Service**: Port 3003 - `/journal/*`
- **Quest Service**: Port 3004 - `/challenge/*`
- **Gateway Service**: Port 3000 - Proxies to other services

## Documentation Structure

```
docs/
├── index.md                # This file
└── api/
    ├── README.md           # Main API documentation
    ├── auth/               # Auth service documentation
    │   └── README.md
    ├── chat/               # Chat service documentation
    │   └── README.md
    ├── gateway/            # Gateway service documentation
    │   └── README.md
    ├── journal/            # Journal service documentation
    │   └── README.md
    └── quest/              # Quest service documentation
        └── README.md
```

## Contributing

When adding new features or modifying existing code, please ensure to:

1. Add JSDoc comments to your functions, classes, and interfaces
2. Run `bun run docs` to regenerate documentation
3. Review the generated markdown files for accuracy

## License

[Your License Here]