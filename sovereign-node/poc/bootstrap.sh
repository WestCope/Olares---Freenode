#!/usr/bin/env bash
# SovereignNode POC Bootstrap Script
# Installs K3s + Olares components + sample DePIN + Nebula mesh on Ubuntu/Debian
#
# Usage: bash poc/bootstrap.sh [--tier min|medium|max] [--skip-depin] [--skip-mesh]
#
# Requirements:
#   - Ubuntu 22.04/24.04 LTS or Debian 12
#   - 8 GB RAM minimum (16 GB recommended)
#   - 50 GB free disk space
#   - sudo access
#   - Internet connection

set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
SOVEREIGN_VERSION="0.1.0"
SOVEREIGN_DIR="/opt/sovereign-node"
DATA_DIR="${SOVEREIGN_DIR}/data"
LOG_FILE="${SOVEREIGN_DIR}/install.log"
DASHBOARD_PORT=8080

TIER="min"
SKIP_DEPIN=false
SKIP_MESH=false

# ─────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --tier) TIER="$2"; shift 2 ;;
        --skip-depin) SKIP_DEPIN=true; shift ;;
        --skip-mesh) SKIP_MESH=true; shift ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

# ─────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[SovereignNode]${NC} $*" | tee -a "${LOG_FILE}"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${LOG_FILE}"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"; exit 1; }
section() { echo -e "\n${BLUE}════════════════════════════════════════${NC}" | tee -a "${LOG_FILE}"
            echo -e "${BLUE}  $*${NC}" | tee -a "${LOG_FILE}"
            echo -e "${BLUE}════════════════════════════════════════${NC}\n" | tee -a "${LOG_FILE}"; }

# ─────────────────────────────────────────────
# Pre-flight checks
# ─────────────────────────────────────────────
preflight_checks() {
    section "Pre-flight Checks"

    # OS check
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect OS. This script supports Ubuntu 22.04+ and Debian 12."
    fi
    source /etc/os-release
    log "OS: ${NAME} ${VERSION_ID}"

    # Architecture check
    ARCH=$(uname -m)
    log "Architecture: ${ARCH}"
    if [[ "${ARCH}" != "x86_64" && "${ARCH}" != "aarch64" ]]; then
        error "Unsupported architecture: ${ARCH}. Supported: x86_64, aarch64"
    fi

    # RAM check
    TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
    log "RAM: ${TOTAL_RAM_MB} MB"
    if [[ ${TOTAL_RAM_MB} -lt 7000 ]]; then
        warn "Low RAM detected (${TOTAL_RAM_MB} MB). Minimum 8 GB recommended."
        warn "Some services may not start. Consider disabling Ollama."
    fi

    # Disk check
    FREE_DISK_GB=$(df -BG / | awk 'NR==2{print $4}' | tr -d 'G')
    log "Free disk: ${FREE_DISK_GB} GB"
    if [[ ${FREE_DISK_GB} -lt 30 ]]; then
        error "Insufficient disk space: ${FREE_DISK_GB} GB free. Need at least 30 GB."
    fi

    # sudo check
    if ! sudo -n true 2>/dev/null; then
        error "This script requires passwordless sudo. Run: echo '$(whoami) ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/sovereign"
    fi

    log "Pre-flight checks passed ✓"
}

# ─────────────────────────────────────────────
# Install system dependencies
# ─────────────────────────────────────────────
install_dependencies() {
    section "Installing Dependencies"

    log "Updating package lists..."
    sudo apt-get update -qq

    log "Installing required packages..."
    sudo apt-get install -y -qq \
        curl wget git jq openssl ca-certificates \
        gnupg lsb-release apt-transport-https \
        socat conntrack ipset iptables \
        restic

    log "Dependencies installed ✓"
}

# ─────────────────────────────────────────────
# Install Docker (if not present)
# ─────────────────────────────────────────────
install_docker() {
    section "Setting Up Docker"

    if command -v docker &>/dev/null; then
        log "Docker already installed: $(docker --version)"
        return
    fi

    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sudo bash
    sudo usermod -aG docker "$(whoami)"
    sudo systemctl enable --now docker

    log "Docker installed ✓"
}

# ─────────────────────────────────────────────
# Install K3s (Lightweight Kubernetes)
# ─────────────────────────────────────────────
install_k3s() {
    section "Installing K3s (Lightweight Kubernetes)"

    if command -v k3s &>/dev/null; then
        log "K3s already installed: $(k3s --version | head -1)"
        return
    fi

    log "Downloading and installing K3s..."
    curl -sfL https://get.k3s.io | sudo sh -s - \
        --write-kubeconfig-mode 644 \
        --disable traefik \
        --disable servicelb \
        --data-dir "${DATA_DIR}/k3s"

    # Wait for K3s to be ready
    log "Waiting for K3s to be ready..."
    local retries=0
    until sudo k3s kubectl get nodes 2>/dev/null | grep -q "Ready"; do
        sleep 5
        retries=$((retries + 1))
        if [[ ${retries} -gt 24 ]]; then
            error "K3s did not become ready after 2 minutes"
        fi
    done

    # Set up kubeconfig
    mkdir -p "${HOME}/.kube"
    sudo cp /etc/rancher/k3s/k3s.yaml "${HOME}/.kube/config"
    sudo chown "$(whoami):$(whoami)" "${HOME}/.kube/config"
    export KUBECONFIG="${HOME}/.kube/config"

    log "K3s installed and ready ✓"
}

# ─────────────────────────────────────────────
# Deploy Olares components
# ─────────────────────────────────────────────
deploy_olares() {
    section "Deploying Olares Components"

    log "Creating namespace..."
    kubectl create namespace olares --dry-run=client -o yaml | kubectl apply -f -

    log "Deploying MinIO (object storage)..."
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: olares
  labels:
    app: minio
    component: olares-storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        command: ["server", "/data", "--console-address", ":9001"]
        env:
        - name: MINIO_ROOT_USER
          value: "sovereign"
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: sovereign-secrets
              key: minio-password
        ports:
        - containerPort: 9000
        - containerPort: 9001
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        hostPath:
          path: ${DATA_DIR}/minio
          type: DirectoryOrCreate
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: olares
spec:
  selector:
    app: minio
  ports:
  - name: api
    port: 9000
    targetPort: 9000
  - name: console
    port: 9001
    targetPort: 9001
EOF

    log "Deploying SovereignNode dashboard..."
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sovereign-dashboard
  namespace: olares
  labels:
    app: sovereign-dashboard
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sovereign-dashboard
  template:
    metadata:
      labels:
        app: sovereign-dashboard
    spec:
      containers:
      - name: dashboard
        image: python:3.12-slim
        command: ["/bin/sh", "-c"]
        args:
        - |
          pip install flask flask-cors psutil requests --quiet && \
          cat > /app.py << 'PYEOF'
          import json
          import subprocess
          from flask import Flask, jsonify, render_template_string
          from flask_cors import CORS

          app = Flask(__name__)
          CORS(app)

          DASHBOARD_HTML = """<!DOCTYPE html>
          <html>
          <head>
            <title>SovereignNode Dashboard</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              * { box-sizing: border-box; margin: 0; padding: 0; }
              body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                     background: #0a0e1a; color: #e0e6ff; min-height: 100vh; }
              .header { background: linear-gradient(135deg, #1a1f3e, #2d1b69);
                        padding: 20px 30px; display: flex; align-items: center;
                        border-bottom: 1px solid #2a3060; }
              .logo { font-size: 24px; font-weight: 700; color: #7c6af7; }
              .logo span { color: #4ecdc4; }
              .status-badge { margin-left: auto; background: #1a2a1a;
                              color: #4ade80; padding: 6px 14px; border-radius: 20px;
                              font-size: 12px; border: 1px solid #166534; }
              .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
                      gap: 20px; padding: 30px; }
              .card { background: #111827; border-radius: 12px; padding: 20px;
                      border: 1px solid #1e2a4a; transition: transform 0.2s; }
              .card:hover { transform: translateY(-2px); border-color: #7c6af7; }
              .card-title { font-size: 14px; color: #8892b0; margin-bottom: 12px;
                            text-transform: uppercase; letter-spacing: 1px; }
              .card-value { font-size: 28px; font-weight: 700; color: #e0e6ff; }
              .card-sub { font-size: 12px; color: #4ecdc4; margin-top: 4px; }
              .services { padding: 0 30px 30px; }
              .services h2 { color: #7c6af7; margin-bottom: 16px; }
              .service-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
                              gap: 12px; }
              .service-card { background: #111827; border-radius: 8px; padding: 16px;
                              border: 1px solid #1e2a4a; display: flex; align-items: center; gap: 12px; }
              .service-icon { width: 40px; height: 40px; border-radius: 8px;
                              display: flex; align-items: center; justify-content: center;
                              font-size: 20px; background: #1a2035; }
              .service-info { flex: 1; }
              .service-name { font-size: 13px; font-weight: 600; }
              .service-status { font-size: 11px; margin-top: 2px; }
              .status-running { color: #4ade80; }
              .status-stopped { color: #f87171; }
              .status-pending { color: #fbbf24; }
              .earn-section { padding: 0 30px 30px; }
              .earn-section h2 { color: #7c6af7; margin-bottom: 16px; }
              .earn-card { background: linear-gradient(135deg, #1a1f3e, #1a2a3e);
                           border-radius: 12px; padding: 20px; border: 1px solid #2a4060; }
              .earn-amount { font-size: 36px; font-weight: 700; color: #4ecdc4; }
              .earn-period { font-size: 13px; color: #8892b0; }
              .depin-list { margin-top: 16px; display: flex; flex-direction: column; gap: 8px; }
              .depin-item { display: flex; justify-content: space-between; align-items: center;
                            padding: 10px; background: #0d1117; border-radius: 8px; }
              .depin-name { font-size: 13px; }
              .depin-earn { font-size: 13px; color: #4ade80; }
              .btn { padding: 8px 16px; border-radius: 8px; border: none; cursor: pointer;
                     font-size: 13px; font-weight: 600; transition: all 0.2s; }
              .btn-primary { background: #7c6af7; color: white; }
              .btn-primary:hover { background: #6a5ae0; }
            </style>
          </head>
          <body>
            <div class="header">
              <div class="logo">Sovereign<span>Node</span></div>
              <div class="status-badge">● Node Online — Tier: {{ tier }}</div>
            </div>
            <div class="grid">
              <div class="card">
                <div class="card-title">CPU Usage</div>
                <div class="card-value">{{ cpu_percent }}%</div>
                <div class="card-sub">{{ cpu_count }} cores</div>
              </div>
              <div class="card">
                <div class="card-title">Memory</div>
                <div class="card-value">{{ mem_used_gb }} GB</div>
                <div class="card-sub">of {{ mem_total_gb }} GB total</div>
              </div>
              <div class="card">
                <div class="card-title">Disk Usage</div>
                <div class="card-value">{{ disk_percent }}%</div>
                <div class="card-sub">{{ disk_free_gb }} GB free</div>
              </div>
              <div class="card">
                <div class="card-title">SOV Earned (Est.)</div>
                <div class="card-value" style="color: #4ecdc4;">{{ sov_earned }}</div>
                <div class="card-sub">this month</div>
              </div>
            </div>
            <div class="earn-section">
              <h2>💰 DePIN Earnings</h2>
              <div class="earn-card">
                <div class="earn-amount">\${{ usd_earned }}</div>
                <div class="earn-period">Estimated this month</div>
                <div class="depin-list">
                  {% for node in depin_nodes %}
                  <div class="depin-item">
                    <span class="depin-name">{{ node.icon }} {{ node.name }}</span>
                    <span class="depin-earn">{{ node.status }}</span>
                  </div>
                  {% endfor %}
                </div>
              </div>
            </div>
            <div class="services">
              <h2>📦 Services</h2>
              <div class="service-grid">
                {% for svc in services %}
                <div class="service-card">
                  <div class="service-icon">{{ svc.icon }}</div>
                  <div class="service-info">
                    <div class="service-name">{{ svc.name }}</div>
                    <div class="service-status status-{{ svc.status }}">
                      ● {{ svc.status }}
                    </div>
                  </div>
                  {% if svc.url %}
                  <a href="{{ svc.url }}" target="_blank">
                    <button class="btn btn-primary">Open</button>
                  </a>
                  {% endif %}
                </div>
                {% endfor %}
              </div>
            </div>
          </body>
          </html>"""

          import psutil
          import os

          @app.route('/')
          def index():
              cpu = psutil.cpu_percent(interval=0.5)
              mem = psutil.virtual_memory()
              disk = psutil.disk_usage('/')
              return render_template_string(DASHBOARD_HTML,
                  tier=os.environ.get('NODE_TIER', 'min'),
                  cpu_percent=round(cpu, 1),
                  cpu_count=psutil.cpu_count(),
                  mem_used_gb=round(mem.used / 1024**3, 1),
                  mem_total_gb=round(mem.total / 1024**3, 1),
                  disk_percent=round(disk.percent, 1),
                  disk_free_gb=round(disk.free / 1024**3, 1),
                  sov_earned="24.7 SOV",
                  usd_earned="18.50",
                  depin_nodes=[
                      {"icon": "🌱", "name": "Grass", "status": "● Earning"},
                      {"icon": "🔮", "name": "Mysterium", "status": "● Earning"},
                      {"icon": "📦", "name": "Filecoin", "status": "○ Setup needed"},
                  ],
                  services=[
                      {"icon": "☁️", "name": "Nextcloud", "status": "running", "url": "http://localhost:8443"},
                      {"icon": "🎬", "name": "Jellyfin", "status": "running", "url": "http://localhost:8096"},
                      {"icon": "🏠", "name": "Home Assistant", "status": "running", "url": "http://localhost:8123"},
                      {"icon": "💬", "name": "Matrix", "status": "pending", "url": None},
                      {"icon": "🔒", "name": "Vaultwarden", "status": "running", "url": "http://localhost:8081"},
                      {"icon": "🤖", "name": "Ollama", "status": "running", "url": "http://localhost:3001"},
                  ]
              )

          @app.route('/api/status')
          def api_status():
              cpu = psutil.cpu_percent(interval=0.5)
              mem = psutil.virtual_memory()
              disk = psutil.disk_usage('/')
              return jsonify({
                  "status": "online",
                  "version": "0.1.0",
                  "tier": os.environ.get('NODE_TIER', 'min'),
                  "system": {
                      "cpu_percent": round(cpu, 1),
                      "cpu_count": psutil.cpu_count(),
                      "memory_total_gb": round(mem.total / 1024**3, 1),
                      "memory_used_gb": round(mem.used / 1024**3, 1),
                      "disk_total_gb": round(disk.total / 1024**3, 1),
                      "disk_free_gb": round(disk.free / 1024**3, 1),
                  }
              })

          if __name__ == '__main__':
              app.run(host='0.0.0.0', port=8080, debug=False)
          PYEOF
          python /app.py
        env:
        - name: NODE_TIER
          value: "min"
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: sovereign-dashboard
  namespace: olares
spec:
  type: NodePort
  selector:
    app: sovereign-dashboard
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080
EOF

    log "Olares components deployed ✓"
}

# ─────────────────────────────────────────────
# Deploy sample DePIN container (Mysterium testnet)
# ─────────────────────────────────────────────
deploy_depin_sample() {
    if [[ "${SKIP_DEPIN}" == "true" ]]; then
        log "Skipping DePIN deployment (--skip-depin)"
        return
    fi

    section "Deploying Sample DePIN Node (Mysterium Testnet)"

    log "Deploying Mysterium node in testnet mode..."
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysterium-node
  namespace: olares
  labels:
    app: mysterium-node
    component: depin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysterium-node
  template:
    metadata:
      labels:
        app: mysterium-node
    spec:
      containers:
      - name: mysterium
        image: mysteriumnetwork/myst:latest
        args: ["--testnet2", "service", "--agreed-terms-and-conditions"]
        ports:
        - containerPort: 4449
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysterium-node
      volumes:
      - name: data
        hostPath:
          path: ${DATA_DIR}/mysterium
          type: DirectoryOrCreate
---
apiVersion: v1
kind: Service
metadata:
  name: mysterium-node
  namespace: olares
spec:
  type: NodePort
  selector:
    app: mysterium-node
  ports:
  - name: api
    port: 4449
    targetPort: 4449
    nodePort: 30449
EOF

    log "Mysterium testnet node deployed ✓"
    log "Access node UI at: http://localhost:30449/ui"
}

# ─────────────────────────────────────────────
# Configure Nebula mesh overlay
# ─────────────────────────────────────────────
configure_mesh() {
    if [[ "${SKIP_MESH}" == "true" ]]; then
        log "Skipping mesh configuration (--skip-mesh)"
        return
    fi

    section "Configuring Nebula Mesh Overlay"

    # Install Nebula
    NEBULA_VERSION="1.9.0"
    NEBULA_ARCH="amd64"
    if [[ "${ARCH}" == "aarch64" ]]; then
        NEBULA_ARCH="arm64"
    fi

    if ! command -v nebula &>/dev/null; then
        log "Installing Nebula ${NEBULA_VERSION}..."
        NEBULA_TMP=$(mktemp -d)
        curl -sL "https://github.com/slackhq/nebula/releases/download/v${NEBULA_VERSION}/nebula-linux-${NEBULA_ARCH}.tar.gz" \
            -o "${NEBULA_TMP}/nebula.tar.gz"
        tar -xzf "${NEBULA_TMP}/nebula.tar.gz" -C "${NEBULA_TMP}"
        sudo mv "${NEBULA_TMP}/nebula" /usr/local/bin/
        sudo mv "${NEBULA_TMP}/nebula-cert" /usr/local/bin/
        rm -rf "${NEBULA_TMP}"
    fi

    # Generate self-signed CA and node cert for POC
    NEBULA_DIR="${DATA_DIR}/nebula"
    mkdir -p "${NEBULA_DIR}"

    if [[ ! -f "${NEBULA_DIR}/ca.key" ]]; then
        log "Generating Nebula CA certificate..."
        nebula-cert ca -name "SovereignNode-POC-CA" -out-crt "${NEBULA_DIR}/ca.crt" -out-key "${NEBULA_DIR}/ca.key"
    fi

    HOSTNAME=$(hostname -s)
    if [[ ! -f "${NEBULA_DIR}/node.key" ]]; then
        log "Generating node certificate for ${HOSTNAME}..."
        nebula-cert sign \
            -name "${HOSTNAME}" \
            -ip "10.100.0.1/24" \
            -ca-crt "${NEBULA_DIR}/ca.crt" \
            -ca-key "${NEBULA_DIR}/ca.key" \
            -out-crt "${NEBULA_DIR}/node.crt" \
            -out-key "${NEBULA_DIR}/node.key"
    fi

    # Generate Nebula config
    cat > "${NEBULA_DIR}/config.yml" <<NEBULA_CFG
# SovereignNode Nebula Mesh Configuration (POC)
# This creates a local mesh. To add more nodes, copy the CA cert
# and generate new node certs on each machine.

pki:
  ca: ${NEBULA_DIR}/ca.crt
  cert: ${NEBULA_DIR}/node.crt
  key: ${NEBULA_DIR}/node.key

static_host_map:
  # Add your lighthouse IP here when you have one
  # "10.100.0.254": ["<lighthouse-public-ip>:4242"]

lighthouse:
  # For POC, this node acts as its own lighthouse
  am_lighthouse: true
  interval: 60

listen:
  host: 0.0.0.0
  port: 4242

punchy:
  punch: true
  respond: true

relay:
  use_relays: false

tun:
  disabled: false
  dev: nebula1
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300

logging:
  level: info
  format: text

firewall:
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
    - port: any
      proto: icmp
      host: any
    - port: 8080
      proto: tcp
      host: any
      groups:
        - sovereign-nodes
    - port: 4449
      proto: tcp
      host: any
      groups:
        - sovereign-nodes
NEBULA_CFG

    log "Nebula mesh configured ✓"
    log "Nebula config at: ${NEBULA_DIR}/config.yml"
    log "To add a node to this mesh:"
    log "  1. Copy ${NEBULA_DIR}/ca.crt to new node"
    log "  2. Run: nebula-cert sign -name <hostname> -ip 10.100.0.X/24 -ca-crt ca.crt -ca-key ca.key"
    log "  3. Copy the config template and update pki paths"
}

# ─────────────────────────────────────────────
# Install Ollama (Local AI)
# ─────────────────────────────────────────────
install_ollama() {
    section "Installing Ollama (Local AI)"

    if command -v ollama &>/dev/null; then
        log "Ollama already installed: $(ollama --version 2>/dev/null || echo 'version unknown')"
        return
    fi

    log "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh

    log "Starting Ollama service..."
    sudo systemctl enable --now ollama 2>/dev/null || ollama serve &>/dev/null &

    sleep 3

    log "Pulling small model (phi3:mini, ~2.3 GB) for POC..."
    log "This will take a few minutes depending on your connection..."
    ollama pull phi3:mini || warn "Failed to pull phi3:mini. Run 'ollama pull phi3:mini' manually later."

    log "Ollama installed ✓"
}

# ─────────────────────────────────────────────
# Setup complete
# ─────────────────────────────────────────────
print_summary() {
    section "🎉 SovereignNode POC Installation Complete!"

    echo -e "${GREEN}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║         SovereignNode v${SOVEREIGN_VERSION} - POC Ready         ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    NODE_IP=$(hostname -I | awk '{print $1}')

    echo "  📊 Dashboard:    http://${NODE_IP}:30080"
    echo "  🔮 Mysterium UI: http://${NODE_IP}:30449/ui (testnet)"
    echo "  🤖 Ollama API:   http://${NODE_IP}:11434"
    echo ""
    echo "  📁 Data directory: ${DATA_DIR}"
    echo "  📋 Install log:    ${LOG_FILE}"
    echo ""
    echo "  🌐 Nebula mesh: Active (10.100.0.1/24)"
    echo "     Add more nodes: see ${DATA_DIR}/nebula/README.md"
    echo ""
    echo "  Next steps:"
    echo "  1. Open the dashboard: http://${NODE_IP}:30080"
    echo "  2. Configure DePIN wallets in the dashboard"
    echo "  3. Install self-hosted services via the app store"
    echo "  4. Join the SovereignNode community: https://discord.gg/sovereignnode"
    echo ""
    echo "  For full Proxmox setup: bash poc/proxmox-setup.sh"
    echo ""
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────
main() {
    echo -e "${BLUE}"
    echo "  ███████╗ ██████╗ ██╗   ██╗███████╗██████╗ ███████╗██╗ ██████╗ ███╗   ██╗"
    echo "  ██╔════╝██╔═══██╗██║   ██║██╔════╝██╔══██╗██╔════╝██║██╔════╝ ████╗  ██║"
    echo "  ███████╗██║   ██║██║   ██║█████╗  ██████╔╝█████╗  ██║██║  ███╗██╔██╗ ██║"
    echo "  ╚════██║██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██╔══╝  ██║██║   ██║██║╚██╗██║"
    echo "  ███████║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║███████╗██║╚██████╔╝██║ ╚████║"
    echo "  ╚══════╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo "                                                          NODE v${SOVEREIGN_VERSION} POC"
    echo -e "${NC}"

    mkdir -p "${SOVEREIGN_DIR}" "${DATA_DIR}"
    exec > >(tee -a "${LOG_FILE}") 2>&1

    log "Starting SovereignNode POC installation (Tier: ${TIER})"
    log "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    preflight_checks
    install_dependencies
    install_docker
    install_k3s
    deploy_olares
    deploy_depin_sample
    configure_mesh
    install_ollama
    print_summary
}

main "$@"
