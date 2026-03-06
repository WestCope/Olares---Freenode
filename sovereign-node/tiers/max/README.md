# Tier 3: MAX — HA / GPU / Distributed AI

## Recommended Hardware

| Component | Budget Option | Recommended | High-End |
|-----------|--------------|-------------|----------|
| **CPU** | Ryzen 9 5900X | Intel i9-13900K | EPYC/Xeon |
| **RAM** | 64 GB DDR4 | 128 GB DDR5 | 256 GB ECC |
| **GPU** | RTX 3060 12GB | RTX 4070 16GB | RTX 4090 / A100 |
| **Storage** | 2× 2TB NVMe | 2× 4TB NVMe + HDD array | All-NVMe array |
| **Network** | 10 Gbps | 10 Gbps | 25 Gbps |
| **Power** | ~200 W | ~300 W | ~500 W |
| **Cost** | ~$1,500 | ~$3,000 | ~$8,000+ |

### Tested Configurations
- **Budget MAX**: Used Dell PowerEdge R720 + RTX 3060 eGPU
- **Recommended**: Minisforum UM790 Pro + RTX 4070 eGPU (Thunderbolt)
- **High-End**: Custom ITX build: i9-13900K, 128GB, RTX 4090

## Software Stack (adds to Tier 2)

```yaml
# Additional over Tier 1 + Tier 2
gpu_features:
  enabled: true
  passthrough_to_vm: true   # GPU passthrough to AI VM

ai_models:
  ollama:
    - "llama3:70b"           # Full Llama 3 70B (requires 40+ GB VRAM or quantized)
    - "llama3:70b-instruct-q4_0"  # 4-bit quantized, ~40 GB VRAM
    - "mistral-large"        # 123B parameter model
    - "stable-diffusion:xl"  # Image generation
    - "svd:xt"               # Stable Video Diffusion
    - "whisper:large-v3"     # Speech-to-text

distributed_ai:
  enabled: true
  accept_jobs_from_mesh: true   # Earn SOV by running inference for Tier 1 nodes
  max_concurrent_jobs: 4

depin_gpu:
  - ionet-gpu-provider         # io.net GPU node (highest earning)
  - akash-gpu-provider         # Akash GPU workloads
  - bittensor-compute-subnet   # Bittensor compute subnet
  - render-network             # Render Network (if GPU eligible)

streaming:
  sunshine:
    enabled: true              # Game streaming server
    encoders:
      - nvenc                  # NVIDIA GPU encoder (fastest)
      - vaapi                  # Intel/AMD GPU encoder
```

## GPU Passthrough Setup

```bash
# Enable IOMMU and GPU passthrough for AI VM
bash scripts/install/gpu-passthrough-setup.sh

# Parameters:
# --gpu-id    PCI ID of GPU (e.g., 10de:2204 for RTX 3090)
# --vm-id     Proxmox VM ID to attach GPU to
bash scripts/install/gpu-passthrough-setup.sh --gpu-id 10de:2489 --vm-id 100
```

## Expected Earnings (Monthly)

| Network | Type | Estimate |
|---------|------|----------|
| Bandwidth DePINs | Grass + Mysterium | $12–60 |
| Storage | Filecoin | $10–50 |
| Compute | Akash (CPU) | $20–80 |
| GPU compute | io.net + Bittensor | $100–400 |
| Distributed AI | Mesh inference jobs | $20–100 |
| **Total** | | **$162–690** |

ROI at $3,000 hardware: ~4–18 months.

## Configuration Files

- [`config.yml`](config.yml) — Tier 3 service configuration
- [`gpu-passthrough.conf`](gpu-passthrough.conf) — GPU passthrough template
