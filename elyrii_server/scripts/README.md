# Elyrii Server Scripts

This directory contains utility scripts for the Elyrii Server project, including documentation generation.

## Documentation Generation

The documentation generation has been moved to this `scripts` folder to avoid conflicts with the microservices' bun projects.

### Quick Start

Generate documentation for all services:
```bash
./generate-docs.sh
```

Or use the npm/bun script from the project root:
```bash
bun run docs
```

### Available Commands

From within the `scripts` directory:
```bash
# Install dependencies
bun install

# Generate docs for all services
bun run docs:all

# Generate docs for specific services
bun run docs:auth
bun run docs:chat
bun run docs:gateway

# Clean generated documentation
bun run docs:clean

# Serve documentation locally
bun run docs:serve
```

Using the shell script:
```bash
./generate-docs.sh all      # Generate all docs (default)
./generate-docs.sh auth     # Generate auth service docs only
./generate-docs.sh chat     # Generate chat service docs only
./generate-docs.sh gateway  # Generate gateway service docs only
./generate-docs.sh serve    # Start documentation server
./generate-docs.sh clean    # Clean generated docs
```

### Configuration

- **TypeDoc Configuration**: `typedoc.json` - Main configuration for documentation generation
- **Package Dependencies**: `package.json` - Contains TypeDoc and related dependencies
- **Output Directory**: `../docs/api/` - Generated documentation is placed here

### Why Separate from Root?

The documentation generation was moved to the `scripts` folder to:
1. Avoid dependency conflicts with microservices
2. Keep the root package.json clean and focused on workspace management
3. Isolate documentation tooling from service code
4. Prevent TypeDoc dependencies from interfering with service builds

### Microservice TypeDoc Configs

Each microservice maintains its own `typedoc.json` for service-specific documentation:
- `../services/auth/typedoc.json`
- `../services/chat/typedoc.json`
- `../services/gateway/typedoc.json`
