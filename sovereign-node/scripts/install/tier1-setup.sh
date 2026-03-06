#!/usr/bin/env bash
# SovereignNode — Tier 1 Setup Script
# Standalone alternative to the Ansible playbook for single-node setups
# Usage: bash scripts/install/tier1-setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOVEREIGN_DIR="/opt/sovereign-node"
DATA_DIR="${SOVEREIGN_DIR}/data"
SOVEREIGN_USER="${SUDO_USER:-$(whoami)}"

source "${SCRIPT_DIR}/../lib/common.sh" 2>/dev/null || true

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()     { echo -e "${GREEN}[Install]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
section() { echo -e "\n${BLUE}──── $* ────${NC}\n"; }

section "SovereignNode Tier 1 Setup"

# ── Prompt for configuration ─────────────────────────────────────────────────
read -r -p "Nextcloud admin password [auto-generate]: " NC_PASS
NC_PASS="${NC_PASS:-$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 16)}"

read -r -p "PostgreSQL password [auto-generate]: " PG_PASS
PG_PASS="${PG_PASS:-$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 24)}"

read -r -p "Grass username (email) [skip]: " GRASS_USER
read -r -p "Grass password [skip]: " GRASS_PASS
read -r -p "Mysterium wallet address (0x...) [skip]: " MYST_WALLET

# ── Create directories ────────────────────────────────────────────────────────
log "Creating directories..."
sudo mkdir -p "${DATA_DIR}"/{nextcloud,media,homeassistant,matrix,bitwarden,nebula,mysterium,backups,wallet}
sudo chown -R "${SOVEREIGN_USER}:${SOVEREIGN_USER}" "${SOVEREIGN_DIR}"

# ── Write .env file ────────────────────────────────────────────────────────────
ENV_FILE="${SOVEREIGN_DIR}/.env"
log "Writing configuration to ${ENV_FILE}..."
cat > "${ENV_FILE}" <<EOF
# SovereignNode Configuration — DO NOT COMMIT THIS FILE
SOVEREIGN_DATA_PATH=${DATA_DIR}
NODE_HOSTNAME=$(hostname -s)
NODE_TIER=min

# Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=${NC_PASS}

# PostgreSQL
POSTGRES_PASSWORD=${PG_PASS}

# DePIN
GRASS_USERNAME=${GRASS_USER}
GRASS_PASSWORD=${GRASS_PASS}
MYSTERIUM_WALLET=${MYST_WALLET}

# Backup (configure after setup)
# RESTIC_REPOSITORY=s3:s3.amazonaws.com/your-bucket
# RESTIC_PASSWORD=$(openssl rand -base64 32)
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=

# Dashboard
PORT=8080
EOF
chmod 600 "${ENV_FILE}"

# ── Install Docker ────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sudo bash
    sudo usermod -aG docker "${SOVEREIGN_USER}"
fi

# ── Copy and start Docker Compose ────────────────────────────────────────────
log "Copying Tier 1 Docker Compose..."
REPO_DIR="$(dirname "${SCRIPT_DIR}")/.."
cp "${REPO_DIR}/sovereign-node/tiers/min/docker-compose.yml" "${SOVEREIGN_DIR}/docker-compose.yml"

log "Starting services..."
cd "${SOVEREIGN_DIR}"
docker compose up -d 2>/dev/null || \
    sudo docker compose --env-file "${ENV_FILE}" up -d

# ── Install Ollama ─────────────────────────────────────────────────────────────
log "Installing Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh || warn "Ollama install failed, skipping"

# ── Setup dashboard ────────────────────────────────────────────────────────────
log "Installing dashboard dependencies..."
pip3 install flask flask-cors psutil requests --quiet 2>/dev/null || \
    sudo pip3 install flask flask-cors psutil requests --quiet

log "Starting SovereignNode dashboard..."
NODE_TIER=min SOVEREIGN_DATA_PATH="${DATA_DIR}" \
    python3 "${REPO_DIR}/sovereign-node/dashboard/app.py" &
echo $! > "${SOVEREIGN_DIR}/dashboard.pid"

# ── Print summary ──────────────────────────────────────────────────────────────
NODE_IP=$(hostname -I | awk '{print $1}')
echo ""
log "════════════════════════════════════════════"
log "  Tier 1 Setup Complete!"
log "  Dashboard:  http://${NODE_IP}:8080"
log "  Nextcloud:  http://${NODE_IP}:8443"
log "  Jellyfin:   http://${NODE_IP}:8096"
log "  Config:     ${ENV_FILE}"
log "════════════════════════════════════════════"
log ""
log "Next: Configure backup in ${ENV_FILE}, then:"
log "  bash scripts/install/setup-backup.sh"
