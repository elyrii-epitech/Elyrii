#!/bin/bash

# Elyrii Server Documentation Generator
# This script generates documentation for the monolithic server

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
COMMAND=${1:-build}

case $COMMAND in
    build)
        echo "📚 Generating documentation..."
        bun run docs:build
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
        echo "Usage: $0 [build|serve|clean]"
        echo ""
        echo "Commands:"
        echo "  build    - Generate documentation (default)"
        echo "  serve    - Start local documentation server"
        echo "  clean    - Clean generated documentation"
        exit 1
        ;;
esac

echo ""
echo "✅ Documentation generation complete!"
echo "📁 Output location: $ROOT_DIR/docs/"
