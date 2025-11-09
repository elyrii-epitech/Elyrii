#!/bin/bash
# Start local development environment

set -e

echo "🚀 Starting Elyrii local development environment..."

# Check for GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "⚠️  Warning: nvidia-smi not found. GPU may not be available."
    echo "Make sure NVIDIA Docker runtime is installed."
fi

# Check if .env.local exists
if [ ! -f .env.local ]; then
    echo "📝 Creating .env.local from template..."
    cp .env.local.template .env.local 2>/dev/null || cat > .env.local << 'EOF'
# Local Development Environment
AI_MODEL=mistralai/Mistral-7B-Instruct-v0.2
HF_TOKEN=your_token_here
TENSOR_PARALLEL_SIZE=1
GPU_MEMORY_UTILIZATION=0.85
MAX_MODEL_LEN=4096
EOF
    echo "⚠️  Please edit .env.local and add your HF_TOKEN"
fi

# Load environment
export $(cat .env.local | grep -v '^#' | xargs)

echo "📦 Starting services with Docker Compose..."
docker-compose up -d

echo ""
echo "⏳ Waiting for services to start (this may take 2-5 minutes)..."
echo "   - GPU machine needs to download model (~15GB)"
echo "   - Model loading takes additional 1-2 minutes"
echo ""

# Wait for controller
echo "Waiting for controller..."
until curl -s http://localhost:8080/health > /dev/null 2>&1; do
    printf "."
    sleep 2
done
echo " ✓ Controller ready"

# Wait for GPU
echo "Waiting for GPU machine..."
until curl -s http://localhost:8000/health > /dev/null 2>&1; do
    printf "."
    sleep 5
done
echo " ✓ GPU machine ready"

echo ""
echo "✅ Local environment is ready!"
echo ""
echo "📊 Services:"
echo "  Controller: http://localhost:8080"
echo "  GPU (vLLM): http://localhost:8000"
echo ""
echo "💡 Useful commands:"
echo "  docker-compose logs -f controller   - View controller logs"
echo "  docker-compose logs -f vllm-gpu     - View GPU logs"
echo "  docker-compose down                 - Stop all services"
echo "  ./scripts/local_test.sh             - Run tests"
echo ""
echo "🧪 Run tests with:"
echo "  ./scripts/local_test.sh"
