"""
SovereignNode Dashboard — Flask Application
Provides the management UI and REST API for SovereignNode.
"""

import json
import os
import subprocess
import logging
from datetime import datetime, timezone
from functools import wraps

import psutil
import requests
from flask import Flask, jsonify, render_template, request, abort
from flask_cors import CORS

app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": "*"}})

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────
NODE_TIER = os.environ.get("NODE_TIER", "min")
DATA_DIR = os.environ.get("SOVEREIGN_DATA_PATH", "/opt/sovereign-node/data")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
MYSTERIUM_URL = os.environ.get("MYSTERIUM_URL", "http://localhost:4449")


# ─────────────────────────────────────────────────────────────────────────────
# Helper: safe external API call
# ─────────────────────────────────────────────────────────────────────────────
def safe_get(url: str, timeout: float = 2.0) -> dict:
    """GET an external API endpoint; return {} on any error."""
    try:
        resp = requests.get(url, timeout=timeout)
        resp.raise_for_status()
        return resp.json()
    except Exception:
        return {}


# ─────────────────────────────────────────────────────────────────────────────
# System metrics
# ─────────────────────────────────────────────────────────────────────────────
def get_system_metrics() -> dict:
    cpu = psutil.cpu_percent(interval=0.5)
    mem = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    net = psutil.net_io_counters()
    return {
        "cpu_percent": round(cpu, 1),
        "cpu_count": psutil.cpu_count(logical=True),
        "cpu_count_physical": psutil.cpu_count(logical=False),
        "memory_total_gb": round(mem.total / 1024**3, 2),
        "memory_used_gb": round(mem.used / 1024**3, 2),
        "memory_percent": round(mem.percent, 1),
        "disk_total_gb": round(disk.total / 1024**3, 2),
        "disk_used_gb": round(disk.used / 1024**3, 2),
        "disk_free_gb": round(disk.free / 1024**3, 2),
        "disk_percent": round(disk.percent, 1),
        "net_bytes_sent_mb": round(net.bytes_sent / 1024**2, 2),
        "net_bytes_recv_mb": round(net.bytes_recv / 1024**2, 2),
    }


# ─────────────────────────────────────────────────────────────────────────────
# Service status (checks if port is listening)
# ─────────────────────────────────────────────────────────────────────────────
def check_service_port(host: str, port: int, timeout: float = 1.0) -> bool:
    import socket
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except (ConnectionRefusedError, TimeoutError, OSError):
        return False


SERVICES = [
    {"id": "nextcloud", "name": "Nextcloud", "icon": "☁️", "port": 8443,
     "category": "storage", "description": "Self-hosted cloud storage (Google Drive alternative)"},
    {"id": "jellyfin", "name": "Jellyfin", "icon": "🎬", "port": 8096,
     "category": "media", "description": "Media server (Netflix alternative)"},
    {"id": "homeassistant", "name": "Home Assistant", "icon": "🏠", "port": 8123,
     "category": "smart-home", "description": "Smart home automation hub"},
    {"id": "synapse", "name": "Matrix/Synapse", "icon": "💬", "port": 8448,
     "category": "communication", "description": "Encrypted messaging server"},
    {"id": "vaultwarden", "name": "Vaultwarden", "icon": "🔒", "port": 8081,
     "category": "security", "description": "Password manager (Bitwarden-compatible)"},
    {"id": "ollama", "name": "Ollama", "icon": "🤖", "port": 11434,
     "category": "ai", "description": "Local LLM inference server"},
    {"id": "ollama-webui", "name": "Open WebUI", "icon": "🖥️", "port": 3001,
     "category": "ai", "description": "Web interface for Ollama models"},
]

DEPIN_NODES = [
    {"id": "grass", "name": "Grass", "icon": "🌱", "type": "bandwidth",
     "description": "Residential bandwidth sharing", "docs_url": "https://getgrass.io"},
    {"id": "mysterium", "name": "Mysterium", "icon": "🔮", "type": "bandwidth",
     "description": "Decentralized VPN exit node", "api_port": 4449,
     "docs_url": "https://mysterium.network"},
    {"id": "filecoin", "name": "Filecoin", "icon": "📦", "type": "storage",
     "description": "Distributed storage provider", "docs_url": "https://filecoin.io"},
    {"id": "akash", "name": "Akash", "icon": "⚡", "type": "compute",
     "description": "Decentralized cloud compute", "docs_url": "https://akash.network"},
    {"id": "ionet", "name": "io.net", "icon": "💻", "type": "gpu-compute",
     "description": "GPU compute marketplace", "docs_url": "https://io.net"},
    {"id": "bittensor", "name": "Bittensor", "icon": "🧠", "type": "ai-compute",
     "description": "AI model compute network", "docs_url": "https://bittensor.com"},
]


def get_services_status() -> list:
    result = []
    for svc in SERVICES:
        is_up = check_service_port("localhost", svc["port"])
        result.append({
            **svc,
            "status": "running" if is_up else "stopped",
            "url": f"http://localhost:{svc['port']}" if is_up else None,
        })
    return result


def get_depin_status() -> list:
    result = []
    for node in DEPIN_NODES:
        status = "stopped"
        details = {}

        if node["id"] == "mysterium":
            data = safe_get(f"{MYSTERIUM_URL}/api/v1/node/monitoring-status")
            if data:
                status = "running"
                details = data

        result.append({
            **node,
            "status": status,
            "details": details,
        })
    return result


# ─────────────────────────────────────────────────────────────────────────────
# Ollama integration
# ─────────────────────────────────────────────────────────────────────────────
def get_ollama_models() -> list:
    data = safe_get(f"{OLLAMA_URL}/api/tags")
    return data.get("models", [])


# ─────────────────────────────────────────────────────────────────────────────
# Routes — Web UI
# ─────────────────────────────────────────────────────────────────────────────
@app.route("/")
def index():
    return render_template("index.html",
                           tier=NODE_TIER,
                           services=get_services_status(),
                           depin_nodes=get_depin_status(),
                           system=get_system_metrics(),
                           ollama_models=get_ollama_models())


@app.route("/apps")
def apps():
    return render_template("apps.html", tier=NODE_TIER, services=get_services_status())


@app.route("/earnings")
def earnings():
    return render_template("earnings.html", tier=NODE_TIER, depin_nodes=get_depin_status())


@app.route("/ai")
def ai_page():
    return render_template("ai.html", tier=NODE_TIER, models=get_ollama_models())


@app.route("/mesh")
def mesh():
    return render_template("mesh.html", tier=NODE_TIER)


@app.route("/settings")
def settings():
    return render_template("settings.html", tier=NODE_TIER)


# ─────────────────────────────────────────────────────────────────────────────
# Routes — REST API
# ─────────────────────────────────────────────────────────────────────────────
@app.route("/api/status")
def api_status():
    return jsonify({
        "status": "online",
        "version": "0.1.0",
        "tier": NODE_TIER,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "system": get_system_metrics(),
    })


@app.route("/api/services")
def api_services():
    return jsonify(get_services_status())


@app.route("/api/depins")
def api_depins():
    return jsonify(get_depin_status())


@app.route("/api/ai/models")
def api_ai_models():
    models = get_ollama_models()
    return jsonify({"models": models, "count": len(models)})


@app.route("/api/ai/pull", methods=["POST"])
def api_ai_pull():
    """Pull an Ollama model by name."""
    body = request.get_json(silent=True) or {}
    model_name = body.get("model", "").strip()
    if not model_name:
        abort(400, description="'model' field required")
    # Validate model name format to prevent command injection.
    # Ollama model names follow the pattern: name[:tag] or namespace/name[:tag]
    # Only allow alphanumerics, hyphens, underscores, dots, forward-slash
    # (for namespaced models like "myuser/mymodel"), and a single colon for the tag.
    import re
    if not re.match(r'^[a-zA-Z0-9_\-][a-zA-Z0-9_.\-]*(\/[a-zA-Z0-9_.\-]+)?(:[a-zA-Z0-9_.\-]+)?$', model_name):
        abort(400, description="Invalid model name format")
    try:
        result = subprocess.run(
            ["ollama", "pull", model_name],
            capture_output=True,
            text=True,
            timeout=300,
            check=False,
        )
        if result.returncode == 0:
            return jsonify({"status": "success", "model": model_name})
        return jsonify({"status": "error", "error": result.stderr}), 500
    except FileNotFoundError:
        return jsonify({"status": "error", "error": "Ollama not installed"}), 503
    except subprocess.TimeoutExpired:
        return jsonify({"status": "error", "error": "Pull timed out"}), 504


@app.route("/api/ai/chat", methods=["POST"])
def api_ai_chat():
    """Proxy a chat completion request to Ollama."""
    body = request.get_json(silent=True) or {}
    if not body.get("model") or not body.get("messages"):
        abort(400, description="'model' and 'messages' fields required")
    try:
        resp = requests.post(f"{OLLAMA_URL}/api/chat", json=body, timeout=120)
        return jsonify(resp.json()), resp.status_code
    except requests.RequestException as exc:
        return jsonify({"error": str(exc)}), 503


@app.route("/api/system")
def api_system():
    return jsonify(get_system_metrics())


@app.route("/api/node/info")
def api_node_info():
    hostname = os.uname().nodename
    return jsonify({
        "hostname": hostname,
        "tier": NODE_TIER,
        "version": "0.1.0",
        "os": f"{os.uname().sysname} {os.uname().release}",
        "uptime_seconds": int(datetime.now(timezone.utc).timestamp() - psutil.boot_time()),
    })


@app.route("/health")
def health():
    return jsonify({"status": "ok", "timestamp": datetime.now(timezone.utc).isoformat()})


# ─────────────────────────────────────────────────────────────────────────────
# Error handlers
# ─────────────────────────────────────────────────────────────────────────────
@app.errorhandler(400)
def bad_request(err):
    return jsonify({"error": str(err)}), 400


@app.errorhandler(404)
def not_found(err):
    return jsonify({"error": "Not found"}), 404


@app.errorhandler(500)
def internal_error(err):
    logger.exception("Internal server error")
    return jsonify({"error": "Internal server error"}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    debug = os.environ.get("FLASK_DEBUG", "0") == "1"
    logger.info("Starting SovereignNode Dashboard on port %d (tier=%s)", port, NODE_TIER)
    app.run(host="0.0.0.0", port=port, debug=debug)
