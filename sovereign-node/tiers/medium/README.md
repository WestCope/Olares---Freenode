# Tier 2: MEDIUM — Clustering + Light AI

## Recommended Hardware

| Component | Option A (Cluster) | Option B (Single) | Notes |
|-----------|-------------------|-------------------|-------|
| **Nodes** | 2–3 mini PCs | 1 powerful mini PC | Cluster for HA |
| **CPU** | Intel N200/N305 per node | Intel Core i5/i7 N-series | |
| **RAM** | 16–32 GB per node | 32–64 GB | More = more VMs |
| **Storage (OS)** | 256 GB NVMe per node | 512 GB NVMe | |
| **Storage (Data)** | 2–4 TB HDD/SSD | 4–8 TB | Shared storage |
| **Network** | 2.5 Gbps recommended | 2.5 Gbps | Better = more DePIN |
| **Power** | ~25–40 W total | ~35 W | Low power |
| **Cost** | ~$400–800 total | ~$400–600 | |

### Tested Configurations
- **Cluster**: 2× Beelink EQ12 (N305, 32GB) + Synology NAS
- **Single**: Beelink SER5 Max (Ryzen 5 5600H, 32GB, 2TB)
- **Single**: Minisforum UM690 (Ryzen 9 6900HX, 32GB, 1TB)

## Software Stack (adds to Tier 1)

```yaml
# Additional services over Tier 1
additional_services:
  - jitsi-meet         # Self-hosted video conferencing
  - searxng            # Private search engine
  - gitea              # Self-hosted Git
  - immich             # Google Photos alternative

proxmox:
  enabled: true        # Full Proxmox VE hypervisor
  cluster:
    enabled: true      # 2-node cluster (requires even nodes = witness needed)
    nodes: 2

additional_depins:
  - filecoin-lotus     # Storage earning (requires 1 TB+ free)
  - akash-provider     # Compute marketplace
  - ionet-worker       # io.net compute network

ai:
  ollama_models:
    - "llama3:8b"      # Full Llama 3 8B
    - "mistral:7b"     # Mistral 7B instruct
    - "codellama:7b"   # Code generation
    - "llava:7b"       # Vision-language model
```

## Proxmox HA Cluster Setup

With 2+ nodes, SovereignNode enables Proxmox HA clustering:
- **Live migration** of VMs between nodes
- **Automatic failover** if one node goes down
- **Shared storage** via NFS or Ceph (3+ nodes)

```bash
# Setup Proxmox cluster
bash scripts/install/proxmox-cluster-setup.sh --nodes 2

# Or via Ansible:
ansible-playbook -i inventory/hosts.yml playbooks/setup-proxmox-cluster.yml
```

## Expected Earnings (Monthly)

| Network | Type | Estimate |
|---------|------|----------|
| Grass + Mysterium | Bandwidth | $12–60 |
| Filecoin | Storage (2 TB) | $10–40 |
| Akash | Compute | $20–80 |
| **Total** | | **$42–180** |

ROI at $600 hardware: ~3–14 months.

## Configuration Files

- [`config.yml`](config.yml) — Tier 2 service configuration
- [`proxmox-cluster.yml`](proxmox-cluster.yml) — Proxmox cluster config
