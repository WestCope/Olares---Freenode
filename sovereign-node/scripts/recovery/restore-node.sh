#!/usr/bin/env bash
# SovereignNode — Disaster Recovery Script
# Restores a node from Restic backup after hardware failure/loss
#
# Usage: bash scripts/recovery/restore-node.sh \
#           --repo s3:s3.amazonaws.com/my-bucket \
#           --password-file ~/.sovereign-keys/backup-encryption.key \
#           --target /opt/sovereign-node/data

set -euo pipefail

RESTIC_REPO=""
PASSWORD_FILE=""
PASSWORD=""
TARGET_DIR="/opt/sovereign-node/data"
SNAPSHOT="latest"

while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)          RESTIC_REPO="$2"; shift 2 ;;
        --password-file) PASSWORD_FILE="$2"; shift 2 ;;
        --password)      PASSWORD="$2"; shift 2 ;;
        --target)        TARGET_DIR="$2"; shift 2 ;;
        --snapshot)      SNAPSHOT="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[Recovery]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ -z "${RESTIC_REPO}" ]] && err "Provide --repo (e.g. s3:s3.amazonaws.com/my-bucket)"

if [[ -n "${PASSWORD_FILE}" ]]; then
    [[ ! -f "${PASSWORD_FILE}" ]] && err "Password file not found: ${PASSWORD_FILE}"
    export RESTIC_PASSWORD_FILE="${PASSWORD_FILE}"
elif [[ -n "${PASSWORD}" ]]; then
    export RESTIC_PASSWORD="${PASSWORD}"
else
    read -r -s -p "Backup encryption password: " RESTIC_PASS_INPUT
    echo ""
    export RESTIC_PASSWORD="${RESTIC_PASS_INPUT}"
fi

export RESTIC_REPOSITORY="${RESTIC_REPO}"

log "SovereignNode Disaster Recovery"
log "Repository: ${RESTIC_REPO}"
log "Target: ${TARGET_DIR}"
log "Snapshot: ${SNAPSHOT}"

# Check Restic
if ! command -v restic &>/dev/null; then
    log "Installing Restic..."
    sudo apt-get install -y restic 2>/dev/null || \
        curl -fsSL https://github.com/restic/restic/releases/download/v0.16.5/restic_0.16.5_linux_amd64.bz2 | \
        bunzip2 | sudo tee /usr/local/bin/restic > /dev/null
    sudo chmod +x /usr/local/bin/restic
fi

# List snapshots
log "Available snapshots:"
restic snapshots --tag sovereign-node 2>/dev/null || restic snapshots

# Confirm
echo ""
warn "This will OVERWRITE ${TARGET_DIR} with snapshot '${SNAPSHOT}'"
read -r -p "Continue? (yes/no): " CONFIRM
[[ "${CONFIRM}" != "yes" ]] && { log "Aborted."; exit 0; }

# Restore
log "Restoring snapshot '${SNAPSHOT}'..."
sudo mkdir -p "${TARGET_DIR}"
restic restore "${SNAPSHOT}" --target "${TARGET_DIR}" --verbose

log "Restore complete!"
log "Start services: docker compose -f /opt/sovereign-node/docker-compose.yml up -d"
log "Or run: bash poc/bootstrap.sh --skip-download"
