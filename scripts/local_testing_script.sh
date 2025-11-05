
#!/bin/bash
# Local testing script

set -e

echo "🧪 Testing Elyrii locally..."

CONTROLLER_URL="http://localhost:8080"

echo ""
echo "1. Testing controller health..."
curl -s "$CONTROLLER_URL/health" | jq . || echo "Controller not ready yet..."

echo ""
echo "2. Checking GPU status..."
curl -s "$CONTROLLER_URL/gpu/status" | jq . || echo "GPU not ready yet..."

echo ""
echo "3. Sending test message..."
curl -s "$CONTROLLER_URL/chat" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello! Please respond with a short greeting."}' \
  | jq .

echo ""
echo "4. Sending second message..."
curl -s "$CONTROLLER_URL/chat" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"message": "What is 2+2?"}' \
  | jq .

echo ""
echo "✅ Local testing complete!"
