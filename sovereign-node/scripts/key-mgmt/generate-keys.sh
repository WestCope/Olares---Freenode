#!/usr/bin/env bash
# SovereignNode — Key Management & Secure Backup
# Generates, stores, and backs up encryption keys securely.
# Keys are needed for:
#   - Restic backup encryption
#   - Nebula mesh certificates
#   - Solana wallet (SOV token)
#
# Usage: bash scripts/key-mgmt/generate-keys.sh [--output-dir DIR]

set -euo pipefail

OUTPUT_DIR="${SOVEREIGN_KEYS_DIR:-${HOME}/.sovereign-keys}"
BACKUP_DIR="${OUTPUT_DIR}/backup"

while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[KeyMgmt]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

log "SovereignNode Key Management"
log "Output directory: ${OUTPUT_DIR}"

# Create secure directory
mkdir -p "${OUTPUT_DIR}" "${BACKUP_DIR}"
chmod 700 "${OUTPUT_DIR}" "${BACKUP_DIR}"

# ── 1. Backup Encryption Key (Restic) ─────────────────────────────────────────
RESTIC_KEY_FILE="${OUTPUT_DIR}/backup-encryption.key"
if [[ ! -f "${RESTIC_KEY_FILE}" ]]; then
    log "Generating Restic backup encryption key..."
    # Generate a strong 256-bit key and encode as base64
    openssl rand -base64 32 > "${RESTIC_KEY_FILE}"
    chmod 400 "${RESTIC_KEY_FILE}"
    log "Restic key saved: ${RESTIC_KEY_FILE}"
else
    log "Restic key already exists: ${RESTIC_KEY_FILE}"
fi

# ── 2. Nebula CA and Node Certificates ────────────────────────────────────────
NEBULA_DIR="${OUTPUT_DIR}/nebula"
mkdir -p "${NEBULA_DIR}"
chmod 700 "${NEBULA_DIR}"

if command -v nebula-cert &>/dev/null; then
    if [[ ! -f "${NEBULA_DIR}/ca.key" ]]; then
        log "Generating Nebula CA certificate..."
        HOSTNAME=$(hostname -s)
        nebula-cert ca \
            -name "SovereignNode-${HOSTNAME}-CA" \
            -out-crt "${NEBULA_DIR}/ca.crt" \
            -out-key "${NEBULA_DIR}/ca.key"
        chmod 400 "${NEBULA_DIR}/ca.key"
        log "Nebula CA generated: ${NEBULA_DIR}/ca.{crt,key}"
    fi

    if [[ ! -f "${NEBULA_DIR}/node.key" ]]; then
        log "Generating Nebula node certificate..."
        HOSTNAME=$(hostname -s)
        nebula-cert sign \
            -name "${HOSTNAME}" \
            -ip "10.100.0.1/24" \
            -ca-crt "${NEBULA_DIR}/ca.crt" \
            -ca-key "${NEBULA_DIR}/ca.key" \
            -out-crt "${NEBULA_DIR}/node.crt" \
            -out-key "${NEBULA_DIR}/node.key"
        chmod 400 "${NEBULA_DIR}/node.key"
        log "Node cert generated: ${NEBULA_DIR}/node.{crt,key}"
    fi
else
    warn "nebula-cert not found. Install Nebula first, then re-run this script."
fi

# ── 3. Solana Wallet (SOV Token) ──────────────────────────────────────────────
WALLET_DIR="${OUTPUT_DIR}/solana"
mkdir -p "${WALLET_DIR}"
chmod 700 "${WALLET_DIR}"

WALLET_FILE="${WALLET_DIR}/keypair.json"
if [[ ! -f "${WALLET_FILE}" ]]; then
    if command -v solana-keygen &>/dev/null; then
        log "Generating Solana wallet keypair..."
        solana-keygen new \
            --no-bip39-passphrase \
            --outfile "${WALLET_FILE}" \
            --silent
        chmod 400 "${WALLET_FILE}"
        PUBKEY=$(solana-keygen pubkey "${WALLET_FILE}")
        log "Solana wallet created: ${PUBKEY}"
        log "Public key: ${PUBKEY}"
    else
        warn "solana-keygen not found. Install Solana CLI to generate wallet."
        warn "Install: sh -c \"\$(curl -sSfL https://release.solana.com/stable/install)\""
    fi
fi

# ── 4. Generate Recovery Document ─────────────────────────────────────────────
RECOVERY_DOC="${OUTPUT_DIR}/RECOVERY-INSTRUCTIONS.txt"
RESTIC_KEY_VALUE=$(cat "${RESTIC_KEY_FILE}" 2>/dev/null || echo "<not generated>")
SOLANA_PUBKEY=""
if [[ -f "${WALLET_FILE}" ]] && command -v solana-keygen &>/dev/null; then
    SOLANA_PUBKEY=$(solana-keygen pubkey "${WALLET_FILE}" 2>/dev/null || echo "<unable to read>")
fi

cat > "${RECOVERY_DOC}" <<EOF
═══════════════════════════════════════════════════════════
  SovereignNode Key Recovery Document
  Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
  Hostname: $(hostname)
═══════════════════════════════════════════════════════════

IMPORTANT: Store this document in multiple secure locations:
  - Printed physical copy in a safe
  - Encrypted USB drive stored separately from your node
  - Bitwarden/1Password vault (NOT on the node itself)

═══════════════════════════════════════════════════════════
1. BACKUP ENCRYPTION KEY (Restic)
   Used to decrypt ALL backups from this node.
   WITHOUT THIS KEY, BACKUPS CANNOT BE RESTORED.

   Key: ${RESTIC_KEY_VALUE}
   File: ${RESTIC_KEY_FILE}

═══════════════════════════════════════════════════════════
2. SOLANA WALLET (SOV Token Earnings)
   Public key: ${SOLANA_PUBKEY}
   Keypair file: ${WALLET_FILE}

   To backup: copy the keypair JSON file to a secure location.
   Import into Phantom/Solflare using the private key.

═══════════════════════════════════════════════════════════
3. NEBULA MESH CA
   CA cert: ${NEBULA_DIR}/ca.crt
   CA key:  ${NEBULA_DIR}/ca.key (KEEP SECRET)

   The CA key is needed to add new nodes to your mesh.
   Back up BOTH the CA cert and key.

═══════════════════════════════════════════════════════════
RECOVERY STEPS (if node is lost/stolen):
  1. Get new hardware, install Ubuntu/Debian
  2. Run: bash sovereign-node/poc/bootstrap.sh
  3. Restore Restic backup using the key above:
     export RESTIC_REPOSITORY=<your-backup-destination>
     export RESTIC_PASSWORD=<key-from-above>
     restic restore latest --target /opt/sovereign-node/data
  4. Import Solana wallet using keypair JSON
  5. Regenerate Nebula node cert with CA key

EOF
chmod 400 "${RECOVERY_DOC}"

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
log "════════════════════════════════════════════════"
log "  Key generation complete!"
log ""
log "  Keys directory: ${OUTPUT_DIR}"
log "  Recovery doc:   ${RECOVERY_DOC}"
log ""
warn "  ⚠️  CRITICAL SECURITY NOTICE:"
warn "  The recovery document at ${RECOVERY_DOC} contains"
warn "  your backup ENCRYPTION KEY in PLAINTEXT."
warn ""
warn "  Before backing up the recovery doc to any cloud service"
warn "  (Bitwarden, Google Drive, etc.), encrypt it first:"
warn "    gpg --symmetric --cipher-algo AES256 ${RECOVERY_DOC}"
warn "    # Then back up the .gpg file; delete the original"
warn ""
warn "  NEVER email, message, or share this file unencrypted."
warn "  See: docs/key-mgmt/best-practices.md"
log "════════════════════════════════════════════════"
echo ""

# ── Optional: sync to Syncthing ───────────────────────────────────────────────
if command -v syncthing &>/dev/null; then
    warn "Syncthing detected. Consider adding ${OUTPUT_DIR} to Syncthing for redundant key backup."
    warn "IMPORTANT: Only sync to trusted devices you physically control."
fi
