# Tier 1: MIN — Basic Earning & Self-Hosting

## Recommended Hardware

| Component | Budget Option | Recommended | Notes |
|-----------|--------------|-------------|-------|
| **CPU** | Intel N100 (4-core) | Intel N200/N305 | ARM: RPi 5 works |
| **RAM** | 8 GB DDR4 | 16 GB DDR4/DDR5 | More = more containers |
| **Storage (OS)** | 128 GB SSD | 256 GB NVMe | NVMe preferred |
| **Storage (Data)** | 1 TB HDD | 2 TB HDD/SSD | For Nextcloud/Jellyfin |
| **Network** | 100 Mbps | 1 Gbps | Critical for DePIN earning |
| **Power** | ~10–15 W | ~10–15 W | Very low power |
| **Cost** | ~$150 | ~$200–300 | One-time hardware cost |

### Tested Devices
- **Beelink Mini S12 Pro** (N100, 16GB, 500GB) — Best value for Tier 1
- **Raspberry Pi 5** (8GB) + USB SSD — ARM, great for DePIN
- **Zimaboard 832** — x86, very low power
- **Orange Pi 5** — Powerful ARM with NPU

## Software Stack

```yaml
# Tier 1 services (all run as Docker/K3s containers)
services:
  - nextcloud          # Cloud storage (replaces Google Drive)
  - jellyfin           # Media server (replaces Netflix)
  - home-assistant     # Smart home hub
  - matrix-synapse     # Encrypted chat
  - bitwarden          # Password manager

depins:
  - grass              # Bandwidth sharing ($5–20/month)
  - mysterium          # VPN exit node ($5–30/month)
  - uprock             # Bandwidth sharing ($2–10/month)

mesh:
  - nebula             # Overlay VPN (connects all your nodes)
  - netbird            # WireGuard mesh

ai:
  - ollama             # Small LLMs: Llama 3.2 3B, Phi-3 mini

backup:
  - restic             # Client-side encrypted backups to cloud
```

## Quick Setup

```bash
# From the sovereign-node directory:
bash scripts/install/tier1-setup.sh

# Or use Ansible:
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/setup-tier1.yml
```

## Resource Requirements

| Service | CPU | RAM | Storage |
|---------|-----|-----|---------|
| Nextcloud | 0.5 core | 512 MB | 1–2 TB (data) |
| Jellyfin | 1–2 core (transcode) | 1 GB | Media storage |
| Home Assistant | 0.2 core | 256 MB | 10 GB |
| Matrix/Synapse | 0.3 core | 512 MB | 20 GB |
| Grass node | 0.1 core | 128 MB | Minimal |
| Mysterium node | 0.1 core | 128 MB | Minimal |
| Ollama (Phi-3) | 2–4 core | 4 GB | 5 GB model |
| **Total** | **~4 cores** | **~7–8 GB** | **~30 GB + data** |

This fits comfortably on 16 GB RAM hardware.

## Expected Earnings (Monthly Estimates)

These are community-reported estimates and vary significantly by location, bandwidth quality, and market conditions.

| Network | Type | Estimate |
|---------|------|----------|
| Grass | Bandwidth proxy | $5–20 |
| Mysterium | VPN bandwidth | $5–30 |
| UpRock | Bandwidth | $2–10 |
| **Total** | | **$12–60** |

At $200 hardware cost, ROI in approximately 3–16 months.

## Configuration Files

- [`config.yml`](config.yml) — Tier 1 service configuration
- [`docker-compose.yml`](docker-compose.yml) — Complete stack definition
