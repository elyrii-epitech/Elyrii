# Elyrii Server API Documentation

Welcome to the Elyrii Server API documentation. This documentation is auto-generated from the TypeScript source code using TypeDoc.

## Services

The Elyrii server consists of three microservices:

### 📦 [Auth Service]()
Handles user authentication, authorization, and session management. Provides secure endpoints for login, registration, and token validation.

### 💬 [Chat Service]()
Manages real-time messaging, chat rooms, and message history. Includes WebSocket support for live communications and Kafka integration for message processing.

### 🌐 [Gateway Service]()
API gateway that routes requests to appropriate microservices. Handles request validation, rate limiting, and response aggregation.

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
```

## API Overview

Each service exposes its own API endpoints:

- **Auth Service**: Port 3001 - `/auth/*`
- **Chat Service**: Port 3002 - `/chat/*`
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
    └── gateway/            # Gateway service documentation
        └── README.md
```

## Contributing

When adding new features or modifying existing code, please ensure to:

1. Add JSDoc comments to your functions, classes, and interfaces
2. Run `bun run docs` to regenerate documentation
3. Review the generated markdown files for accuracy

## License

[Your License Here]