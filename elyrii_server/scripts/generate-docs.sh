#!/bin/bash

# Elyrii Server Documentation Generator
# This script generates documentation for all microservices

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 Elyrii Server Documentation Generator"
echo "========================================="
echo ""

cd "$SCRIPT_DIR"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing documentation dependencies..."
    bun install
    echo ""
fi

# Parse command line arguments
COMMAND=${1:-all}

case $COMMAND in
    all)
        echo "📚 Generating documentation for all services..."
        bun run docs:all
        ;;
    auth)
        echo "🔐 Generating documentation for auth service..."
        bun run docs:auth
        ;;
    chat)
        echo "💬 Generating documentation for chat service..."
        bun run docs:chat
        ;;
    gateway)
        echo "🌐 Generating documentation for gateway service..."
        bun run docs:gateway
        ;;
    serve)
        echo "🖥️  Starting documentation server on http://localhost:8080..."
        bun run docs:serve
        ;;
    clean)
        echo "🧹 Cleaning documentation output..."
        bun run docs:clean
        ;;
    *)
        echo "Usage: $0 [all|auth|chat|gateway|serve|clean]"
        echo ""
        echo "Commands:"
        echo "  all      - Generate documentation for all services (default)"
        echo "  auth     - Generate documentation for auth service only"
        echo "  chat     - Generate documentation for chat service only"
        echo "  gateway  - Generate documentation for gateway service only"
        echo "  serve    - Start local documentation server"
        echo "  clean    - Clean generated documentation"
        exit 1
        ;;
esac

echo ""
echo "✅ Documentation generation complete!"
echo "📁 Output location: $ROOT_DIR/docs/"
