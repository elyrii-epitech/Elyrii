#!/bin/bash
# Stop local development environment

echo "🛑 Stopping Elyrii local environment..."

docker-compose down

echo "✅ Services stopped"
echo ""
echo "💡 To keep model cache (faster restart):"
echo "  - Cache is preserved in Docker volume"
echo ""
echo "💡 To completely clean up (free disk space):"
echo "  docker-compose down -v  # Removes volumes too"
