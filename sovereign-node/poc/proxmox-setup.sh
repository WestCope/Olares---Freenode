#!/usr/bin/env bash
# SovereignNode Proxmox VE Setup Script
# Configures a fresh Proxmox VE 8.x installation for SovereignNode
#
# Usage: bash poc/proxmox-setup.sh [--tier min|medium|max]
#
# Requirements:
#   - Proxmox VE 8.0+ installed (bare metal or VM)
#   - Root access on the Proxmox host
#   - Internet connection

set -euo pipefail

TIER="${1:-min}"
SOVEREIGN_DIR="/opt/sovereign-node"
DATA_DIR="${SOVEREIGN_DIR}/data"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[Proxmox Setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${BLUE}══════ $* ══════${NC}\n"; }

# ─────────────────────────────────────────────
# Verify running on Proxmox
# ─────────────────────────────────────────────
check_proxmox() {
    if ! command -v pvesh &>/dev/null; then
        error "This script must be run on a Proxmox VE host."
    fi
    PVE_VERSION=$(pvesh get /version --output-format=json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version','unknown'))" 2>/dev/null || echo "unknown")
    log "Proxmox VE version: ${PVE_VERSION}"
}

# ─────────────────────────────────────────────
# Remove Proxmox subscription notice
# ─────────────────────────────────────────────
configure_proxmox_repos() {
    section "Configuring Proxmox Repositories"

    # Disable enterprise repo (requires subscription)
    if [[ -f /etc/apt/sources.list.d/pve-enterprise.list ]]; then
        sed -i 's|^deb|#deb|' /etc/apt/sources.list.d/pve-enterprise.list
        log "Disabled enterprise repository"
    fi

    # Enable community (no-subscription) repo
    cat > /etc/apt/sources.list.d/pve-no-subscription.list <<EOF
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
    log "Enabled community repository"

    # Disable subscription nag popup
    if [[ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]]; then
        # Patch the subscription check (for personal/homelab use)
        cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js \
           /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak
        sed -i "s/if (data.status !== 'Active')/if (false)/g" \
            /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
        log "Removed subscription nag dialog (for homelab use)"
    fi

    apt-get update -qq
}

# ─────────────────────────────────────────────
# Install required packages
# ─────────────────────────────────────────────
install_packages() {
    section "Installing Packages"
    apt-get install -y -qq \
        curl wget git jq python3-pip \
        ansible \
        restic \
        zfsutils-linux \
        net-tools \
        htop iotop

    log "Packages installed ✓"
}

# ─────────────────────────────────────────────
# Configure storage
# ─────────────────────────────────────────────
configure_storage() {
    section "Configuring Storage"

    mkdir -p "${DATA_DIR}"

    # Create directory-based storage for SovereignNode data
    pvesm add dir sovereign-data \
        --path "${DATA_DIR}" \
        --content backup,images,iso,vztmpl \
        --shared 0 2>/dev/null || log "Storage 'sovereign-data' already exists"

    log "Storage configured ✓"
}

# ─────────────────────────────────────────────
# Download Olares VM template
# ─────────────────────────────────────────────
setup_olares_vm() {
    section "Setting Up Olares VM Template"

    VMID=100
    OLARES_ISO_DIR="${DATA_DIR}/iso"
    mkdir -p "${OLARES_ISO_DIR}"

    # Check if VM already exists
    if pvesh get /nodes/$(hostname)/qemu/${VMID}/status/current &>/dev/null; then
        log "VM ${VMID} already exists. Skipping Olares VM creation."
        return
    fi

    log "Creating Olares VM (VM ID: ${VMID})..."
    log "Note: Using Ubuntu 22.04 base image. Download Olares ISO from https://github.com/beclab/Olares"
    log "For full Olares, replace the ISO with the official Olares release image."

    # Download Ubuntu 22.04 cloud image as base (Olares runs on top of Ubuntu)
    UBUNTU_IMG="${OLARES_ISO_DIR}/ubuntu-22.04-minimal-cloudimg-amd64.img"
    if [[ ! -f "${UBUNTU_IMG}" ]]; then
        log "Downloading Ubuntu 22.04 cloud image (base for Olares)..."
        wget -q --show-progress \
            "https://cloud-images.ubuntu.com/minimal/releases/22.04/release/ubuntu-22.04-minimal-cloudimg-amd64.img" \
            -O "${UBUNTU_IMG}" || warn "Failed to download Ubuntu image. Download manually."
    fi

    # Create VM
    qm create ${VMID} \
        --name "olares-sovereign" \
        --memory 4096 \
        --cores 4 \
        --net0 virtio,bridge=vmbr0 \
        --bios ovmf \
        --machine q35 \
        --efidisk0 local-lvm:0,format=raw,efitype=4m \
        --onboot 1 \
        --description "SovereignNode - Olares OS VM (Tier: ${TIER})"

    # Import disk
    if [[ -f "${UBUNTU_IMG}" ]]; then
        qm importdisk ${VMID} "${UBUNTU_IMG}" local-lvm --format raw
        qm set ${VMID} --scsi0 local-lvm:vm-${VMID}-disk-1 --boot order=scsi0
    fi

    # Cloud-init configuration
    qm set ${VMID} \
        --ide2 local-lvm:cloudinit \
        --serial0 socket \
        --vga serial0 \
        --ciuser sovereign \
        --cipassword "$(openssl rand -base64 16)" \
        --ipconfig0 "ip=dhcp"

    log "Olares VM ${VMID} created ✓"
    log "Start VM: qm start ${VMID}"
    log "Then install Olares: bash poc/olares-vm.sh ${VMID}"
}

# ─────────────────────────────────────────────
# Create DePIN LXC containers
# ─────────────────────────────────────────────
setup_depin_containers() {
    section "Creating DePIN LXC Containers"

    # Download Debian template if not present
    if ! pveam list local 2>/dev/null | grep -q "debian-12"; then
        log "Downloading Debian 12 LXC template..."
        pveam update
        pveam download local debian-12-standard_12.7-1_amd64.tar.zst 2>/dev/null || \
            warn "Template download failed. Available templates: pveam available"
    fi

    # Mysterium Network container
    MYST_CTID=200
    if ! pvesh get /nodes/$(hostname)/lxc/${MYST_CTID}/status/current &>/dev/null; then
        log "Creating Mysterium Network container (CT ${MYST_CTID})..."
        pct create ${MYST_CTID} local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
            --hostname mysterium-node \
            --memory 512 \
            --swap 256 \
            --cores 1 \
            --net0 name=eth0,bridge=vmbr0,ip=dhcp \
            --storage local-lvm \
            --rootfs local-lvm:8 \
            --unprivileged 1 \
            --features nesting=1 \
            --onboot 1 \
            --description "SovereignNode DePIN: Mysterium Network node" \
            2>/dev/null || warn "Failed to create Mysterium CT"

        log "Mysterium container created ✓ (CT ${MYST_CTID})"
        log "Start: pct start ${MYST_CTID}"
        log "Install: pct exec ${MYST_CTID} -- bash /sovereign-node/scripts/install/mysterium-install.sh"
    fi

    log "DePIN containers set up ✓"
}

# ─────────────────────────────────────────────
# Configure automated backups via PBS
# ─────────────────────────────────────────────
configure_backups() {
    section "Configuring Automated Backups"

    # Add backup job (runs daily at 2 AM, keeps 7 backups)
    pvesh create /cluster/backup --id sovereign-daily \
        --enabled 1 \
        --schedule "0 2 * * *" \
        --storage local \
        --mode snapshot \
        --compress zstd \
        --maxfiles 7 \
        --all 1 \
        --notes-template "SovereignNode backup - {{guestname}}" \
        2>/dev/null || log "Backup job 'sovereign-daily' already exists"

    log "Automated backups configured ✓"
    log "Backups: daily at 2 AM, 7 copies retained"
}

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
print_summary() {
    section "🎉 Proxmox Setup Complete!"
    NODE_IP=$(hostname -I | awk '{print $1}')
    echo "  🖥  Proxmox UI:   https://${NODE_IP}:8006"
    echo "  📦 VM 100:       Olares OS (start: qm start 100)"
    echo "  📦 CT 200:       Mysterium DePIN node"
    echo ""
    echo "  Next: bash poc/olares-vm.sh to install Olares in VM 100"
    echo "  Then: Open https://${NODE_IP}:8006 for Proxmox dashboard"
    echo ""
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────
check_proxmox
configure_proxmox_repos
install_packages
configure_storage
setup_olares_vm
setup_depin_containers
configure_backups
print_summary
