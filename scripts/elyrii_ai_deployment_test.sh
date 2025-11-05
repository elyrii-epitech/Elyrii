#!/bin/bash
# Test the deployed system

set -e

CONTROLLER_URL="${CONTROLLER_URL:-https://elyrii-controller.fly.dev}"

echo "🧪 Testing Elyrii deployment..."

echo ""
echo "1. Testing controller health..."
curl -s "$CONTROLLER_URL/health" | jq .

echo ""
echo "2. Checking GPU status..."
curl -s "$CONTROLLER_URL/gpu/status" | jq .

echo ""
echo "3. Sending test message (this will start GPU if stopped)..."
echo "⏳ This may take 2-3 minutes on first run (model loading)..."
curl -s "$CONTROLLER_URL/chat" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello! Please respond with a short greeting."}' \
  | jq .

echo ""
echo "4. Sending second message (should be instant)..."
curl -s "$CONTROLLER_URL/chat" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"message": "What is 2+2?"}' \
  | jq .

echo ""
echo "✅ Testing complete!"
echo "GPU will auto-stop after 5 minutes of inactivity"
