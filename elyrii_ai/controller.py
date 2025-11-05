"""
Controller service for managing GPU machine lifecycle.
Handles authentication, request routing, and GPU auto-start.
"""

import os
import time
import logging
import requests
import asyncio
from typing import Optional, Dict, Any
from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Elyrii Controller", version="1.0.0")

# CORS configuration for mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
FLY_API_TOKEN = os.getenv("FLY_API_TOKEN")
GPU_APP_NAME = os.getenv("GPU_APP_NAME", "elyrii-vllm-gpu")
GPU_INTERNAL_URL = os.getenv("GPU_INTERNAL_URL", "http://elyrii-vllm-gpu.internal:8000")
STARTUP_TIMEOUT = int(os.getenv("STARTUP_TIMEOUT", "180"))
IDLE_TIMEOUT = int(os.getenv("IDLE_TIMEOUT", "300"))  # 5 minutes


class ChatRequest(BaseModel):
    message: str
    temperature: Optional[float] = 0.7
    max_tokens: Optional[int] = 2048
    stream: Optional[bool] = False


class ChatResponse(BaseModel):
    response: str
    model: str
    gpu_status: str
    processing_time: float


class GPUManager:
    """Manages GPU machine lifecycle on Fly.io."""
    
    def __init__(self):
        self.last_request_time = 0
        self.gpu_status = "stopped"

    async def is_gpu_running(self) -> bool:
        """Check if GPU machine is running."""
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(f"{GPU_INTERNAL_URL}/health")
                return response.status_code == 200
        except:
            return False

    async def start_gpu_machine(self) -> bool:
        """Start the GPU machine via Fly.io API."""
        if not FLY_API_TOKEN:
            logger.error("FLY_API_TOKEN not set")
            return False
        
        logger.info(f"Starting GPU machine: {GPU_APP_NAME}")
        
        try:
            headers = {
                "Authorization": f"Bearer {FLY_API_TOKEN}",
                "Content-Type": "application/json"
            }
            
            # Get machine list
            async with httpx.AsyncClient() as client:
                machines_url = f"https://api.machines.dev/v1/apps/{GPU_APP_NAME}/machines"
                response = await client.get(machines_url, headers=headers)
                
                if response.status_code != 200:
                    logger.error(f"Failed to get machines: {response.text}")
                    return False
                
                machines = response.json()
                if not machines:
                    logger.error("No GPU machines found")
                    return False
                
                machine_id = machines[0]["id"]
                logger.info(f"Found machine: {machine_id}")
                
                # Start the machine
                start_url = f"{machines_url}/{machine_id}/start"
                response = await client.post(start_url, headers=headers)
                
                if response.status_code not in [200, 202]:
                    logger.error(f"Failed to start machine: {response.text}")
                    return False
                
                logger.info("GPU machine start initiated")
                self.gpu_status = "starting"
                return True
                
        except Exception as e:
            logger.error(f"Error starting GPU machine: {e}")
            return False
    
    async def wait_for_gpu_ready(self, timeout: int = STARTUP_TIMEOUT) -> bool:
        """Wait for GPU machine to be ready."""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            if await self.is_gpu_running():
                logger.info("GPU machine is ready")
                self.gpu_status = "running"
                return True
            
            logger.info("Waiting for GPU machine...")
            await asyncio.sleep(5)
        
        logger.error("GPU machine startup timeout")
        self.gpu_status = "timeout"
        return False
    
    async def forward_request_to_gpu(
        self, 
        request: ChatRequest
    ) -> Dict[str, Any]:
        """Forward chat request to GPU machine."""
        self.last_request_time = time.time()
        
        url = f"{GPU_INTERNAL_URL}/v1/chat/completions"
        payload = {
            "model": os.getenv("AI_MODEL", "mistralai/Mistral-7B-Instruct-v0.2"),
            "messages": [{"role": "user", "content": request.message}],
            "temperature": request.temperature,
            "max_tokens": request.max_tokens,
            "stream": False
        }
        
        try:
            async with httpx.AsyncClient(timeout=300.0) as client:
                response = await client.post(url, json=payload)
                response.raise_for_status()
                return response.json()
        except Exception as e:
            logger.error(f"Error forwarding to GPU: {e}")
            raise HTTPException(status_code=502, detail=str(e))
    
    def get_idle_time(self) -> float:
        """Get time since last request in seconds."""
        if self.last_request_time == 0:
            return 0
        return time.time() - self.last_request_time


# Global GPU manager instance
gpu_manager = GPUManager()


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "status": "ok",
        "service": "elyrii-controller",
        "gpu_status": gpu_manager.gpu_status,
        "idle_time": gpu_manager.get_idle_time()
    }


@app.get("/health")
async def health():
    """Health check."""
    return {"status": "healthy"}


@app.get("/gpu/status")
async def gpu_status():
    """Get GPU machine status."""
    is_running = await gpu_manager.is_gpu_running()
    return {
        "running": is_running,
        "status": gpu_manager.gpu_status,
        "idle_time": gpu_manager.get_idle_time(),
        "idle_timeout": IDLE_TIMEOUT
    }


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Handle chat request with automatic GPU startup.
    """
    start_time = time.time()
    
    # Check if GPU is running
    if not await gpu_manager.is_gpu_running():
        logger.info("GPU machine not running, starting...")
        
        # Start GPU machine
        if not await gpu_manager.start_gpu_machine():
            raise HTTPException(
                status_code=503, 
                detail="Failed to start GPU machine"
            )
        
        # Wait for GPU to be ready
        if not await gpu_manager.wait_for_gpu_ready():
            raise HTTPException(
                status_code=503,
                detail="GPU machine startup timeout"
            )
    
    # Forward request to GPU
    try:
        result = await gpu_manager.forward_request_to_gpu(request)
        
        response_content = result["choices"][0]["message"]["content"]
        processing_time = time.time() - start_time
        
        return ChatResponse(
            response=response_content,
            model=result.get("model", "unknown"),
            gpu_status="running",
            processing_time=processing_time
        )
        
    except Exception as e:
        logger.error(f"Error processing chat request: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/chat/stream")
async def chat_stream(request: ChatRequest):
    """
    Handle streaming chat request.
    """
    # Ensure GPU is running
    if not await gpu_manager.is_gpu_running():
        await gpu_manager.start_gpu_machine()
        await gpu_manager.wait_for_gpu_ready()
    
    # Stream from GPU
    url = f"{GPU_INTERNAL_URL}/v1/chat/completions"
    payload = {
        "model": os.getenv("AI_MODEL"),
        "messages": [{"role": "user", "content": request.message}],
        "temperature": request.temperature,
        "max_tokens": request.max_tokens,
        "stream": True
    }
    
    async def event_stream():
        async with httpx.AsyncClient(timeout=300.0) as client:
            async with client.stream("POST", url, json=payload) as response:
                async for line in response.aiter_lines():
                    if line:
                        yield f"{line}\n"
    
    from fastapi.responses import StreamingResponse
    return StreamingResponse(event_stream(), media_type="text/event-stream")


if __name__ == "__main__":
    import uvicorn
    import asyncio
    
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=int(os.getenv("PORT", "8080")),
        log_level="info"
    )
