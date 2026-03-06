# SovereignNode Full Install Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start (Ubuntu/Debian)](#quick-start)
3. [Proxmox VE Setup](#proxmox-ve-setup)
4. [Configuring DePIN Nodes](#configuring-depin-nodes)
5. [Setting Up Mesh Networking](#setting-up-mesh-networking)
6. [Key Management & Backup](#key-management--backup)
7. [Monitoring & Maintenance](#monitoring--maintenance)

---

## Prerequisites

### Minimum Requirements (Tier 1)
- CPU: x86_64 or ARM64 (4+ cores recommended)
- RAM: 8 GB minimum, 16 GB recommended
- Storage: 50 GB OS + data storage (SSD recommended)
- OS: Ubuntu 22.04 LTS / Ubuntu 24.04 LTS / Debian 12
- Network: Stable internet connection (100+ Mbps for DePIN)
- Power: Continuous operation (connected to power, not battery-only)

### Recommended for Tier 2/3
- RAM: 32–128 GB
- Storage: NVMe SSD (500 GB+)
- Network: 1 Gbps connection

---

## Quick Start

### Option A: Bootstrap Script (Easiest)

```bash
# Clone the repository
git clone https://github.com/WestCope/Olares---Freenode.git
cd Olares---Freenode/sovereign-node

# Run bootstrap (installs K3s + Olares + DePIN + mesh)
bash poc/bootstrap.sh

# Or with options:
bash poc/bootstrap.sh --tier min --skip-depin
```

### Option B: Manual Docker Compose

```bash
# Copy environment file
cp tiers/min/docker-compose.yml .
cp .env.example .env

# Edit .env with your settings
nano .env

# Start services
docker compose up -d

# Check status
docker compose ps
```

### Option C: Ansible (Multi-node / Fleet)

```bash
# Edit inventory
cp ansible/inventory/hosts.yml.template ansible/inventory/hosts.yml
nano ansible/inventory/hosts.yml

# Run setup playbook
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/setup-tier1.yml
```

---

## Proxmox VE Setup

For Tier 2/3 with full virtualization support:

### 1. Install Proxmox VE

1. Download Proxmox VE ISO from https://www.proxmox.com/en/downloads
2. Flash to USB: `dd if=proxmox-ve_8.x.iso of=/dev/sdX bs=4M status=progress`
3. Boot from USB and follow installer (select ZFS for storage if possible)

### 2. Run SovereignNode Proxmox Setup

```bash
# SSH into your Proxmox host
ssh root@<proxmox-ip>

# Clone and run setup
git clone https://github.com/WestCope/Olares---Freenode.git
cd Olares---Freenode/sovereign-node
bash poc/proxmox-setup.sh
```

This will:
- Remove subscription nag (for homelab use)
- Configure storage pools
- Create Olares VM template
- Set up DePIN LXC containers
- Configure automated backups

### 3. Start Olares VM

```bash
qm start 100
# Follow: bash poc/olares-vm.sh 100
```

---

## Configuring DePIN Nodes

### Mysterium Network (Bandwidth)

```bash
# Start Mysterium node
cd integrations/depins/mysterium
docker compose up -d

# Open setup wizard
xdg-open http://localhost:4449/ui
```

Follow the wizard to:
1. Agree to terms
2. Set payout wallet (MetaMask on Polygon)
3. Enable service types (VPN, datacenter scraping)

### Filecoin Storage (Tier 2+)

Filecoin requires significant setup. See the [Lotus documentation](https://lotus.filecoin.io/storage-providers/setup/).

**Minimum**: 1 TB free space, a Filecoin wallet with some FIL for sealing costs.

```bash
cd integrations/depins/filecoin
export FILECOIN_STORAGE_PATH=/mnt/storage/filecoin
docker compose up -d lotus-daemon

# Wait for chain sync (hours to days depending on connection)
docker exec sn-lotus lotus sync wait
```

---

## Setting Up Mesh Networking

### Nebula Overlay VPN

```bash
# Generate certificates
bash scripts/key-mgmt/generate-keys.sh

# Start Nebula
cd integrations/meshes/nebula
docker compose up -d

# Verify mesh
ping 10.100.0.1  # Your node's mesh IP
```

### Adding a Second Node

On node 2:
1. Copy `ca.crt` from node 1 to node 2
2. Generate a new node cert: `nebula-cert sign -name node2 -ip 10.100.0.2/24 ...`
3. Use the same `config.yml` template with updated IP
4. Start Nebula on node 2

---

## Key Management & Backup

### Generate All Keys

```bash
bash scripts/key-mgmt/generate-keys.sh
# Output: ~/.sovereign-keys/
```

### Backup Your Keys

**Critical**: Without backup keys, you cannot recover backups or wallet funds.

Options:
1. **Bitwarden** (recommended): Store key values as secure notes
2. **Physical copy**: Print recovery document, store in safe
3. **USB drive**: Encrypted LUKS volume stored physically separate from node
4. **Syncthing**: Sync to another trusted device you own

```bash
# Configure Restic backup with your key
export RESTIC_REPOSITORY="s3:s3.amazonaws.com/my-bucket"
export RESTIC_PASSWORD="$(cat ~/.sovereign-keys/backup-encryption.key)"

# First backup
restic backup /opt/sovereign-node/data

# Schedule daily backups (add to crontab)
0 2 * * * restic backup /opt/sovereign-node/data --tag sovereign-node >> /var/log/sovereign-backup.log
```

---

## Monitoring & Maintenance

### Dashboard

Access the SovereignNode dashboard at http://YOUR-IP:8080

Features:
- System metrics (CPU, RAM, disk)
- Service status
- DePIN earning status
- AI model management

### Grafana Monitoring

Start the full monitoring stack:

```bash
cd poc
docker compose -f depin-compose.yml up -d prometheus grafana

# Access Grafana
xdg-open http://localhost:3000
# Default login: admin / sovereign
```

### Updates

```bash
# Update all services (single node)
docker compose pull && docker compose up -d

# Update fleet via Ansible
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/update-fleet.yml
```

### Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f mysterium-node

# Dashboard
journalctl -u sovereign-dashboard -f
```

---

## Troubleshooting

### Services Not Starting

```bash
# Check service health
docker compose ps
docker compose logs <service-name>

# Check resources
free -h && df -h
```

### DePIN Node Not Earning

- Verify your IP is residential (not VPS/datacenter)
- Check firewall: `sudo ufw status`
- Verify ports are open: `nmap -p 4449,1194 YOUR-IP`
- Check logs: `docker compose logs mysterium-node`

### Nebula Mesh Not Connecting

- Verify port 4242/UDP is open on firewall
- Check lighthouse is accessible: `nc -zv <lighthouse-ip> 4242`
- Verify certificate paths in config.yml

---

## Getting Help

- GitHub Issues: https://github.com/WestCope/Olares---Freenode/issues
- Community Discord: https://discord.gg/sovereignnode
- Documentation: https://docs.sovereignnode.io
