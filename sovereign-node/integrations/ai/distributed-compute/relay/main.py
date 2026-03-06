"""
SovereignNode Distributed AI Compute Relay
Accepts inference requests from low-power mesh nodes,
routes to local Ollama or forwards to higher-tier nodes.

This enables "distributed AI" — a Tier 1 node (8GB RAM) can
request a large model inference from a Tier 3 node (GPU), paying
a small amount of SOV tokens for the compute.
"""

from __future__ import annotations

import os
import logging
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="SovereignNode AI Relay",
    description="Distributed AI inference relay for the SovereignNode mesh",
    version="0.1.0",
)

LOCAL_OLLAMA_URL = os.environ.get("LOCAL_OLLAMA_URL", "http://localhost:11434")
NODE_TIER = os.environ.get("NODE_TIER", "min")

# Models available on each tier (locally)
TIER_MODELS: dict[str, list[str]] = {
    "min":    ["phi3:mini", "llama3.2:3b"],
    "medium": ["llama3:8b", "mistral:7b", "codellama:7b"],
    "max":    ["llama3:70b", "mistral-large", "llava:34b"],
}

LOCAL_MODELS = TIER_MODELS.get(NODE_TIER, [])


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "tier": NODE_TIER}


@app.get("/api/tags")
async def list_models() -> dict[str, Any]:
    """List available models — local + mesh-available."""
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(f"{LOCAL_OLLAMA_URL}/api/tags", timeout=5.0)
            local_models = resp.json().get("models", [])
        except httpx.RequestError:
            local_models = []

    return {
        "models": local_models,
        "relay": {
            "tier": NODE_TIER,
            "local_models": LOCAL_MODELS,
            "mesh_models_available": True,
            "note": "Mesh models require SOV token payment",
        },
    }


@app.post("/api/generate")
async def generate(request: Request) -> Any:
    """Proxy generation request to local Ollama or mesh."""
    body = await request.json()
    model = body.get("model", "")

    # Check if model is available locally
    local_available = any(m in model for m in LOCAL_MODELS)

    if local_available:
        logger.info("Routing %s to local Ollama", model)
        return await _proxy_to_ollama(request, body)
    else:
        logger.info("Model %s not available locally, mesh routing not yet implemented", model)
        raise HTTPException(
            status_code=503,
            detail={
                "error": f"Model '{model}' not available locally on {NODE_TIER} tier.",
                "hint": "Mesh routing to higher-tier nodes coming in v0.2.0",
                "local_models": LOCAL_MODELS,
            },
        )


@app.post("/api/chat")
async def chat(request: Request) -> Any:
    """Proxy chat request to local Ollama or mesh."""
    body = await request.json()
    return await _proxy_to_ollama(request, body)


_ALLOWED_OLLAMA_PATHS = {
    "/api/generate",
    "/api/chat",
    "/api/embeddings",
    "/api/tags",
    "/api/show",
    "/api/pull",
}


async def _proxy_to_ollama(request: Request, body: dict[str, Any]) -> Any:
    """Proxy to local Ollama using a validated allowlist of API paths."""
    path = request.url.path
    if path not in _ALLOWED_OLLAMA_PATHS:
        raise HTTPException(status_code=400, detail=f"Path '{path}' not allowed")
    async with httpx.AsyncClient(timeout=120.0) as client:
        try:
            resp = await client.post(
                f"{LOCAL_OLLAMA_URL}{path}",
                json=body,
                headers={"Content-Type": "application/json"},
            )
            return resp.json()
        except httpx.RequestError as exc:
            raise HTTPException(status_code=503, detail=f"Ollama unavailable: {exc}") from exc


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("RELAY_PORT", 11435))
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")
