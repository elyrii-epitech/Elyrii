# Elyrii Server Documentation

This repository contains the Elyrii server with microservices architecture and auto-generated documentation using TypeDoc.

## Services

- **Auth Service**: Handles authentication and authorization
- **Chat Service**: Manages real-time messaging and chat functionality  
- **Gateway Service**: API gateway for routing and request handling

## Documentation

### Generating Documentation

To generate the complete documentation for all services:

```bash
# Install dependencies (if not already installed)
bun install

# Generate documentation for all services
bun run docs:build

# Or simply
bun run docs
```

### Viewing Documentation

After generation, you can view the documentation locally:

```bash
# Serve the documentation locally
bun run docs:serve
```

Then open http://localhost:8080 in your browser.

### Individual Service Documentation

You can also generate documentation for individual services:

```bash
# Auth service only
bun run docs:auth

# Chat service only  
bun run docs:chat

# Gateway service only
bun run docs:gateway
```

## Project Structure

```
elyrii_server/
├── services/
│   ├── auth/           # Authentication service
│   ├── chat/           # Chat service
│   └── gateway/        # API Gateway service
├── docs/
│   ├── index.html      # Documentation landing page
│   └── api/            # Generated TypeDoc documentation
├── package.json        # Root package configuration
├── typedoc.json        # TypeDoc configuration
└── docker-compose.yml  # Docker orchestration
```

## Development

Each service can be run independently:

```bash
# Run auth service
cd services/auth && bun run dev

# Run chat service  
cd services/chat && bun run dev

# Run gateway service
cd services/gateway && bun run dev
```

Or use Docker Compose to run all services:

```bash
docker-compose up
```

## TypeDoc Configuration

The documentation is configured with:
- Automatic API documentation from TypeScript source
- Service-level documentation separation
- Navigation links between services
- Full type information and JSDoc comments support
- Code examples from comments

### Adding Documentation Comments

Use JSDoc comments in your TypeScript files:

```typescript
/**
 * Authenticates a user with credentials
 * @param username - The user's username
 * @param password - The user's password
 * @returns Authentication token if successful
 * @example
 * ```typescript
 * const token = await authenticate('user@example.com', 'password123');
 * ```
 */
export async function authenticate(username: string, password: string): Promise<string> {
  // Implementation
}
```

## License

[Your License Here]
