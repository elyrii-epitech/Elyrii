import os
from dataclasses import dataclass
from typing import Optional, Literal
from enum import Enum


class DeploymentMode(str, Enum):
    """Deployment modes for different environments."""
    LOCAL = "local"
    FLYIO = "flyio"
    AWS = "aws"
    GCP = "gcp"
    AZURE = "azure"
    GENERIC = "generic"


@dataclass
class AIConfig:
    """
    Cloud-agnostic AI configuration.
    Compatible with Fly.io, AWS, GCP, Azure, and other platforms.
    """

    # Deployment settings
    deployment_mode: DeploymentMode = DeploymentMode(
        os.getenv("DEPLOYMENT_MODE", "local")
    )

    # vLLM API settings (internal or external)
    vllm_base_url: str = os.getenv(
        "VLLM_BASE_URL",
        "http://localhost:8000/v1"
    )

    # Model settings
    model_name: str = os.getenv(
        "AI_MODEL",
        "mistralai/Mistral-7B-Instruct-v0.2"
    )

    # HuggingFace token for gated models (Llama 2, etc.)
    hf_token: Optional[str] = os.getenv("HF_TOKEN")

    # Generation defaults
    default_temperature: float = float(os.getenv("AI_TEMPERATURE", "0.7"))
    default_max_tokens: int = int(os.getenv("AI_MAX_TOKENS", "2048"))
    default_top_p: float = float(os.getenv("AI_TOP_P", "0.95"))

    # Performance settings
    gpu_memory_utilization: float = float(
        os.getenv("GPU_MEMORY_UTILIZATION", "0.85")
    )
    tensor_parallel_size: int = int(os.getenv("TENSOR_PARALLEL_SIZE", "1"))
    max_model_len: int = int(os.getenv("MAX_MODEL_LEN", "4096"))

    # Request settings
    timeout: int = int(os.getenv("AI_TIMEOUT", "300"))

    # Health check settings
    health_check_interval: int = int(os.getenv("HEALTH_CHECK_INTERVAL", "30"))
    startup_timeout: int = int(os.getenv("STARTUP_TIMEOUT", "300"))

    # Fallback API (optional - for when self-hosted is unavailable)
    fallback_api_url: Optional[str] = os.getenv("FALLBACK_API_URL")
    fallback_api_key: Optional[str] = os.getenv("FALLBACK_API_KEY")

    @classmethod
    def from_env(cls) -> "AIConfig":
        """Create configuration from environment variables."""
        return cls()

    def get_vllm_launch_args(self) -> list[str]:
        """
        Generate vLLM launch arguments based on deployment mode.
        Useful for dynamic configuration across platforms.
        """
        args = [
            "--model", self.model_name,
            "--host", "0.0.0.0",
            "--port", "8000",
            "--tensor-parallel-size", str(self.tensor_parallel_size),
            "--gpu-memory-utilization", str(self.gpu_memory_utilization),
            "--max-model-len", str(self.max_model_len),
            "--dtype", "auto",
            "--trust-remote-code",
        ]

        # Add HF token if provided
        if self.hf_token:
            os.environ["HF_TOKEN"] = self.hf_token

        # Platform-specific optimizations
        if self.deployment_mode == DeploymentMode.FLYIO:
            # Fly.io specific settings
            args.extend([
                "--disable-log-requests",  # Reduce logging overhead
                "--max-num-seqs", "32",  # Conservative for Fly.io
            ])
        elif self.deployment_mode == DeploymentMode.AWS:
            # AWS specific settings
            args.extend([
                "--max-num-seqs", "64",
            ])

        return args

    def is_vllm_available(self) -> bool:
        """Check if vLLM endpoint is configured."""
        return bool(self.vllm_base_url)

    def has_fallback(self) -> bool:
        """Check if fallback API is configured."""
        return bool(self.fallback_api_url and self.fallback_api_key)


# Recommended models for different hardware configurations
MODEL_RECOMMENDATIONS = {
    "small_gpu": {
        "name": "mistralai/Mistral-7B-Instruct-v0.2",
        "vram_required": "16GB",
        "description": "7B params, fast inference, good quality",
    },
    "medium_gpu": {
        "name": "meta-llama/Llama-2-13b-chat-hf",
        "vram_required": "24GB",
        "description": "13B params, balanced performance",
    },
    "large_gpu": {
        "name": "mistralai/Mixtral-8x7B-Instruct-v0.1",
        "vram_required": "40GB",
        "description": "MoE model, excellent quality",
    },
    "code_specialized": {
        "name": "codellama/CodeLlama-13b-Instruct-hf",
        "vram_required": "24GB",
        "description": "Optimized for code generation",
    },
}