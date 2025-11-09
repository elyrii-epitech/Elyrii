#!/bin/bash
set -e

# Dynamic entrypoint for vLLM deployment
# Handles configuration across different platforms

echo "Starting vLLM server..."
echo "Model: ${AI_MODEL:-mistralai/Mistral-7B-Instruct-v0.2}"
echo "Deployment mode: ${DEPLOYMENT_MODE:-local}"

# Build vLLM command
CMD="python3 -m vllm.entrypoints.openai.api_server"
CMD="$CMD --model ${AI_MODEL:-mistralai/Mistral-7B-Instruct-v0.2}"
CMD="$CMD --host 0.0.0.0"
CMD="$CMD --port ${PORT:-8000}"
CMD="$CMD --tensor-parallel-size ${TENSOR_PARALLEL_SIZE:-1}"
CMD="$CMD --gpu-memory-utilization ${GPU_MEMORY_UTILIZATION:-0.85}"
CMD="$CMD --max-model-len ${MAX_MODEL_LEN:-4096}"
CMD="$CMD --dtype auto"
CMD="$CMD --trust-remote-code"

# Platform-specific settings
if [ "$DEPLOYMENT_MODE" = "flyio" ]; then
    echo "Applying Fly.io optimizations..."
    CMD="$CMD --disable-log-requests"
    CMD="$CMD --max-num-seqs 32"
fi

# Execute vLLM
echo "Executing: $CMD"
exec $CMD
