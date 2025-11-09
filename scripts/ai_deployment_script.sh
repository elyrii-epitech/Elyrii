#!/bin/bash
# Complete deployment script for Fly.io architecture

set -e

echo "🚀 Deploying Elyrii to Fly.io (Controller + GPU setup)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check fly CLI
if ! command -v fly &> /dev/null; then
    echo -e "${RED}❌ Fly CLI not found${NC}"
    echo "Install from: https://fly.io/docs/hands-on/install-flyctl/"
    exit 1
fi

echo -e "${BLUE}📋 Step 1: Creating GPU machine volume${NC}"
if ! fly volumes list -a elyrii-vllm-gpu 2>/dev/null | grep -q "vllm_models"; then
    echo "Creating 50GB persistent volume..."
    fly volumes create vllm_models \
        --region sjc \
        --size 50 \
        --app elyrii-vllm-gpu \
        --yes
    echo -e "${GREEN}✓ Volume created${NC}"
else
    echo -e "${GREEN}✓ Volume already exists${NC}"
fi

echo -e "${BLUE}📋 Step 2: Setting secrets${NC}"
read -sp "Enter HuggingFace token (press Enter to skip): " HF_TOKEN
echo
if [ -n "$HF_TOKEN" ]; then
    fly secrets set HF_TOKEN="$HF_TOKEN" -a elyrii-vllm-gpu
    echo -e "${GREEN}✓ HF_TOKEN set${NC}"
fi

read -sp "Enter Fly.io API token for controller: " FLY_API_TOKEN
echo
if [ -n "$FLY_API_TOKEN" ]; then
    fly secrets set FLY_API_TOKEN="$FLY_API_TOKEN" -a elyrii-controller
    echo -e "${GREEN}✓ FLY_API_TOKEN set${NC}"
else
    echo -e "${RED}⚠ Warning: Controller needs FLY_API_TOKEN to start GPU machine${NC}"
fi

echo -e "${BLUE}📋 Step 3: Deploying GPU machine${NC}"
fly deploy --config fly_gpu.toml --ha=false
echo -e "${GREEN}✓ GPU machine deployed${NC}"

# Stop GPU machine to save costs
echo "Stopping GPU machine (will auto-start on first request)..."
fly machine stop -a elyrii-vllm-gpu --force 2>/dev/null || true

echo -e "${BLUE}📋 Step 4: Deploying controller${NC}"
fly deploy --config fly_controller.toml --ha=false
echo -e "${GREEN}✓ Controller deployed${NC}"

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "📊 Summary:"
echo "  Controller: https://elyrii-controller.fly.dev"
echo "  GPU Machine: Stopped (auto-starts on request)"
echo "  Volume: 50GB for model weights"
echo ""
echo "💡 Useful commands:"
echo "  fly logs -a elyrii-controller     - View controller logs"
echo "  fly logs -a elyrii-vllm-gpu       - View GPU logs"
echo "  fly status -a elyrii-vllm-gpu     - Check GPU status"
echo "  fly machine stop -a elyrii-vllm-gpu --force - Manually stop GPU"
echo ""
echo "🧪 Test the API:"
echo "  curl https://elyrii-controller.fly.dev/gpu/status"
echo "  curl https://elyrii-controller.fly.dev/chat \\"
echo "    -X POST -H 'Content-Type: application/json' \\"
echo "    -d '{\"message\": \"Hello!\"}'"
