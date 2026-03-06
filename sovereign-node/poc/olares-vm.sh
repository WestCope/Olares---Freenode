#!/usr/bin/env bash
# SovereignNode — Install Olares inside a Proxmox VM
# Usage: bash poc/olares-vm.sh [VM_ID]
#
# This script connects to a running VM and installs Olares OS
# (the open-source personal cloud OS this project builds on).

set -euo pipefail

VMID="${1:-100}"
GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${GREEN}[Olares VM]${NC} $*"; }
section() { echo -e "\n${BLUE}══════ $* ══════${NC}\n"; }

check_vm() {
    if ! command -v qm &>/dev/null; then
        echo "This script must run on a Proxmox host."; exit 1
    fi
    STATUS=$(qm status "${VMID}" 2>/dev/null | awk '{print $2}')
    if [[ "${STATUS}" != "running" ]]; then
        log "Starting VM ${VMID}..."
        qm start "${VMID}"
        sleep 15
    fi
    log "VM ${VMID} is running ✓"
}

install_olares() {
    section "Installing Olares in VM ${VMID}"
    log "This will install Olares (beclab/Olares) inside the VM."
    log "The official Olares installer handles K3s, storage, and services."

    # Execute the official Olares install inside the VM via cloud-init exec
    # In production, this would SSH into the VM; here we document the steps
    cat <<'INSTRUCTIONS'
═══════════════════════════════════════════════════════════════
  To install Olares inside VM 100, SSH into it and run:
═══════════════════════════════════════════════════════════════

  1. Get VM IP:
     qm guest exec 100 -- ip addr show

  2. SSH into VM:
     ssh sovereign@<VM_IP>

  3. Install Olares:
     curl -fsSL https://cn.olares.sh | bash

     Or for international users:
     curl -fsSL https://olares.sh | bash

  4. Follow the setup wizard — it will:
     - Install K3s and all dependencies
     - Set up storage (MinIO, JuiceFS)
     - Deploy the Olares dashboard (port 30180)
     - Create your Olares ID

  5. Access your Olares node at: http://<VM_IP>:30180

  6. Install SovereignNode additions:
     bash /sovereign-node/scripts/install/add-sovereign-layer.sh

═══════════════════════════════════════════════════════════════
INSTRUCTIONS
    log "Instructions printed. Follow the steps above to complete Olares installation."
}

check_vm
install_olares
