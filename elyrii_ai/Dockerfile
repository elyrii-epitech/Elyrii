# Multi-stage Dockerfile for vLLM deployment
# Optimized for Fly.io and other cloud platforms

FROM nvidia/cuda:12.1.0-devel-ubuntu22.04 AS builder

# Install Python and build dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

# Install vLLM and dependencies
RUN pip3 install --no-cache-dir \
    vllm==0.3.0 \
    fastapi \
    uvicorn[standard] \
    requests

# Production stage
FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

# Install Python runtime
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Set working directory
WORKDIR /app

# Copy application code
COPY elyrii_ai/ /app/
RUN rm -rf /app/docs /app/controller
RUN rm -rf /app/vllm_entrypoint.sh

# Create cache directory
RUN mkdir -p /root/.cache/huggingface

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV HF_HOME=/root/.cache/huggingface
ENV TRANSFORMERS_CACHE=/root/.cache/huggingface

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Launch script that handles dynamic configuration
COPY elyrii_ai/vllm_entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]