# SovereignNode

<div align="center">

![SovereignNode](https://img.shields.io/badge/SovereignNode-v0.1.0--poc-blueviolet)
[![License](https://img.shields.io/badge/License-MIT-blue)](../LICENSE)
[![DePIN](https://img.shields.io/badge/DePIN-Enabled-green)](#depin-earning)
[![Privacy](https://img.shields.io/badge/Privacy-First-orange)](#privacy--sovereignty)

**An all-in-one, modular DePIN home node system — sovereign privacy, passive income, and independence from Big Tech.**

[Quick Start](#quick-start) · [Architecture](#architecture) · [Tiers](#hardware-tiers) · [DePIN Earning](#depin-earning) · [POC Demo](#poc-demo) · [Roadmap](#roadmap)

</div>

---

## Why SovereignNode?

In an era of increasing data surveillance, cloud dependency, and centralized control, SovereignNode democratizes technology by:

- 🔐 **Privacy-first self-hosting** — Nextcloud instead of Google Drive, Jellyfin instead of Netflix, Matrix instead of WhatsApp — all on hardware *you* own.
- 💰 **Passive income via DePIN** — Earn cryptocurrency by sharing unused bandwidth, storage, and AI compute through networks like Grass, Mysterium, Filecoin, Akash, and io.net.
- 🌐 **Resilient community meshes** — Nebula/Netbird/Yggdrasil overlays + LoRa (Meshtastic) + Wi-Fi (LibreMesh) for off-grid and outage-resilient operation.
- 🤖 **Local AI** — Run LLMs (via Ollama) locally; low-power nodes borrow compute from high-power nodes in the mesh for video generation and inference.
- 🪙 **SOV token economy** — Micropayments, staking, and governance for the SovereignNode network (Solana-based, low fees).
- 📦 **One-click apps** — A simplified dashboard (built on Olares) hides Proxmox/Kubernetes complexity. End-users click "Install" and everything just works.

This project is crucial for families, creators, small businesses, and communities seeking freedom from Big Tech — with global impact on privacy, DePIN, and decentralized infrastructure.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Dashboard (SovereignNode UI)     │
│           App Store │ Earnings │ Mesh │ Monitoring       │
└─────────────────────────────┬───────────────────────────┘
                               │
┌─────────────────────────────▼───────────────────────────┐
│                  Olares OS Layer (Kubernetes/K3s)        │
│     App Runtime │ Storage (JuiceFS/MinIO) │ Auth/SSO    │
└──────────┬──────────────────┬────────────────────┬──────┘
           │                  │                    │
┌──────────▼──────┐  ┌────────▼──────┐  ┌─────────▼──────┐
│  Self-Hosted    │  │  DePIN Nodes  │  │  Mesh Network   │
│  Services       │  │               │  │                  │
│ • Nextcloud     │  │ • Grass       │  │ • Nebula VPN     │
│ • Jellyfin      │  │ • Mysterium   │  │ • Netbird        │
│ • Home Assist.  │  │ • Filecoin    │  │ • Yggdrasil      │
│ • Matrix/Synaps │  │ • Akash       │  │ • Meshtastic     │
│ • Jitsi         │  │ • io.net      │  │ • LibreMesh      │
│ • Bitwarden     │  │ • Bittensor   │  │                  │
└─────────────────┘  └───────────────┘  └─────────────────┘
           │                  │                    │
┌──────────▼──────────────────▼────────────────────▼──────┐
│              Proxmox VE Hypervisor (Base Layer)          │
│    VMs │ Containers │ HA Clustering │ PBS Backups         │
└─────────────────────────────────────────────────────────┘
           │                  │
┌──────────▼──────┐  ┌────────▼──────────────────────────┐
│  AI Compute     │  │  SOV Token Economy (Solana)        │
│ • Ollama (local)│  │ • Earn SOV for sharing resources   │
│ • Distributed   │  │ • Stake SOV for premium features   │
│   inference     │  │ • Governance voting                │
│ • GPU passthru  │  │ • Marketplace payments             │
└─────────────────┘  └───────────────────────────────────┘
```

---

## Hardware Tiers

SovereignNode supports three tiers, allowing anyone to start small and scale up:

### 🟢 Tier 1: MIN — Basic Earning + Self-Hosting

**Target Hardware:**
- Mini PC: Beelink Mini S12 Pro, Intel N100, 8–16 GB RAM, 256 GB SSD (~$150–200)
- Or: Raspberry Pi 5 (4GB/8GB), Zimaboard, Orange Pi 5

**Capabilities:**
- Self-hosted apps: Nextcloud, Jellyfin, Home Assistant, Matrix
- DePIN earning: Grass (bandwidth), Mysterium (bandwidth), UpRock
- Mesh: Nebula/Netbird overlay VPN
- AI: Small LLMs via Ollama (Llama 3.2 3B, Phi-3 mini)
- Backup: Restic with client-side encryption to Storj/Backblaze

**Expected Monthly Earn:** $5–30 (bandwidth DePINs)

See [`tiers/min/`](tiers/min/) for hardware recommendations and setup scripts.

---

### 🔵 Tier 2: MEDIUM — Clustering + Light AI

**Target Hardware:**
- Mini PC cluster (2–3 nodes): Intel N200/N305, 16–32 GB RAM, 1 TB NVMe SSD (~$300–600 total)
- Or: Used enterprise mini PC (HP EliteDesk, Lenovo ThinkCentre)

**Capabilities (includes all Tier 1, plus):**
- Proxmox HA clustering (2–3 nodes, live migration)
- Ollama: Medium LLMs (Llama 3 8B, Mistral 7B, CodeLlama)
- DePIN: + Filecoin/Storj (storage), Akash (compute), io.net
- K3s multi-node for distributed workloads
- Automated backups to PBS (Proxmox Backup Server)

**Expected Monthly Earn:** $30–100 (bandwidth + storage)

See [`tiers/medium/`](tiers/medium/) for configs.

---

### 🔴 Tier 3: MAX — HA / GPU / Distributed AI

**Target Hardware:**
- Server or powerful workstation: AMD Ryzen 9 / Intel i9, 64+ GB RAM, 2+ TB NVMe, GPU (RTX 3060+)
- Or: GPU mini PC (Minisforum UM790 Pro + eGPU), Used server (Dell PowerEdge R720)

**Capabilities (includes all Tier 1 & 2, plus):**
- GPU passthrough to VMs for AI acceleration
- Ollama GPU mode: Large LLMs (Llama 3 70B, Mistral Large, Stable Diffusion, SVD)
- Distributed AI: Akash GPU provider, io.net GPU node, Bittensor compute
- Full game/AI streaming: Sunshine/Moonlight
- Proxmox Ceph storage cluster

**Expected Monthly Earn:** $100–500+ (compute DePINs + GPU lending)

See [`tiers/max/`](tiers/max/) for configs.

---

## Quick Start

### Prerequisites
- A machine with Ubuntu 22.04/24.04 LTS (or Debian 12) — minimum 8 GB RAM, 100 GB storage
- `curl`, `git`, `sudo` access

### 1-Minute POC Install

```bash
# Clone this repo
git clone https://github.com/WestCope/Olares---Freenode.git
cd Olares---Freenode/sovereign-node

# Run the POC bootstrap script (installs K3s, deploys Olares + sample DePIN + mesh)
bash poc/bootstrap.sh
```

The script will:
1. Install K3s (Kubernetes) and base dependencies
2. Deploy Olares OS components in containers
3. Start a sample DePIN container (Mysterium node — testnet)
4. Configure a Nebula mesh overlay
5. Open the SovereignNode dashboard on port 8080

### Full Proxmox Install (Recommended for Tier 2/3)

```bash
# On a fresh Proxmox VE 8.x node:
bash poc/proxmox-setup.sh
```

See [docs/install-guide.md](docs/install-guide.md) for full instructions.

---

## DePIN Earning

SovereignNode ships with pre-configured containers for the following DePIN networks:

| Network | Type | Min Hardware | Est. Monthly |
|---------|------|-------------|--------------|
| [Grass](https://getgrass.io) | Bandwidth (residential proxy) | Tier 1 | $5–20 |
| [UpRock](https://uprock.com) | Bandwidth | Tier 1 | $2–10 |
| [Mysterium](https://mysterium.network) | Bandwidth (VPN exit node) | Tier 1 | $5–30 |
| [URnetwork](https://ur.network) | Bandwidth sharing | Tier 1 | $2–15 |
| [Helium IoT](https://helium.com) | IoT coverage (requires hotspot HW) | Hardware add-on | $5–50 |
| [Filecoin/Lotus](https://filecoin.io) | Storage | Tier 2 (1 TB+) | $10–50 |
| [Akash](https://akash.network) | Compute | Tier 2+ | $20–100 |
| [io.net](https://io.net) | GPU compute | Tier 3 (GPU) | $50–300 |
| [Bittensor](https://bittensor.com) | AI compute/data | Tier 3 | $50–500 |

See [`integrations/depins/`](integrations/depins/) for Docker Compose files and setup scripts.

---

## Self-Hosted Services

One-click installs (via the SovereignNode dashboard or `scripts/install/`):

| Service | Category | Replaces |
|---------|----------|---------|
| [Nextcloud](https://nextcloud.com) | Cloud storage + office | Google Drive/Docs |
| [Jellyfin](https://jellyfin.org) | Media server | Netflix/Plex |
| [Home Assistant](https://home-assistant.io) | Smart home hub | Google Home/Alexa |
| [Matrix/Synapse](https://matrix.org) | Encrypted chat | WhatsApp/Telegram |
| [Jitsi Meet](https://jitsi.org) | Video conferencing | Zoom/Teams |
| [Bitwarden](https://bitwarden.com) | Password manager | LastPass/1Password |
| [Ollama](https://ollama.ai) | Local LLMs | ChatGPT/Claude |
| [SearXNG](https://searxng.org) | Private search | Google Search |
| [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | Bitwarden-compatible server | |

---

## Mesh Networking

SovereignNode supports multiple overlay and mesh network technologies:

### Software Overlays (Tier 1+)
- **Nebula** — Fast, lightweight encrypted overlay (Slack open-source). Connects all your nodes into one private network.
- **Netbird** — WireGuard-based peer-to-peer VPN, zero-config.
- **Yggdrasil** — End-to-end encrypted IPv6 overlay network.

### Hardware Meshes (Add-on)
- **Meshtastic** (LoRa) — Long-range, off-grid text messaging and sensor data over LoRa radio. Works without internet.
- **LibreMesh** (Wi-Fi) — Community Wi-Fi mesh network firmware (OpenWRT-based). Creates neighborhood mesh.
- **goTenna** — Commercial mesh radio (SDK integration for SovereignNode relay nodes).

See [`integrations/meshes/`](integrations/meshes/) for configs.

---

## AI Features

### Local AI (Ollama)
- Run LLMs locally: Llama 3, Mistral, Phi-3, CodeLlama, Stable Diffusion, Whisper
- CPU inference (Tier 1): small models (1–7B params)
- iGPU/eGPU acceleration (Tier 2/3): medium–large models (7B–70B)
- Accessed via SovereignNode dashboard, REST API, or Open WebUI

### Distributed AI Compute
Low-power nodes can request compute from high-power nodes in the mesh:
1. Tier 1 node sends inference request to mesh
2. Tier 3 (GPU) node picks up job, runs inference
3. Result returned; Tier 1 node pays Tier 3 node in SOV tokens

See [`integrations/ai/distributed-compute/`](integrations/ai/distributed-compute/) for the protocol design.

### Game Streaming (Tier 2/3)
- **Sunshine** server on SovereignNode (GPU node)
- **Moonlight** client on any device (phone, laptop, TV)
- Stream games from your home node to any screen

---

## SOV Token Economy

SovereignNode uses a custom `SOV` token on Solana for micropayments and governance:

- **Earn SOV** — by sharing bandwidth, storage, compute on the network
- **Spend SOV** — to access distributed AI inference, extra storage, premium features
- **Stake SOV** — to gain governance rights and higher priority in the resource marketplace
- **Govern SOV** — vote on network upgrades, fee structures, featured app listings

See [`token/`](token/) for the Solana program code and [`docs/token-economy/whitepaper.md`](docs/token-economy/whitepaper.md) for the full whitepaper.

---

## POC Demo

The [`poc/`](poc/) directory contains a working proof-of-concept:

1. **`poc/bootstrap.sh`** — Full POC on Ubuntu/Debian: K3s + Olares + DePIN + mesh
2. **`poc/proxmox-setup.sh`** — Proxmox VE setup with SovereignNode defaults
3. **`poc/olares-vm.sh`** — Deploy Olares as a Proxmox VM
4. **`poc/depin-compose.yml`** — Docker Compose for sample DePIN stack (Mysterium + Grass)
5. **`poc/mesh-config/`** — Nebula mesh config templates

---

## Project Structure

```
sovereign-node/
├── README.md                   # This file
├── CONTRIBUTING.md             # How to contribute
├── tiers/
│   ├── min/                    # Tier 1: basic earning/self-hosting
│   ├── medium/                 # Tier 2: clustering/light AI
│   └── max/                    # Tier 3: HA/GPU/distributed AI
├── ansible/
│   ├── inventory/              # Host inventory templates
│   ├── playbooks/              # Setup, update, backup playbooks
│   └── roles/                  # Ansible roles (proxmox, olares, depin, mesh, ai)
├── scripts/
│   ├── install/                # Installation scripts
│   ├── key-mgmt/               # Key management & recovery
│   └── recovery/               # Disaster recovery scripts
├── integrations/
│   ├── depins/                 # DePIN node Docker configs
│   ├── meshes/                 # Mesh network configs
│   ├── ai/                     # AI/LLM integrations
│   ├── services/               # Self-hosted service configs
│   └── streaming/              # Game/AI streaming
├── dashboard/                  # SovereignNode UI (Flask)
│   ├── app.py                  # Main Flask application
│   ├── api/                    # REST API endpoints
│   ├── templates/              # Jinja2 HTML templates
│   └── static/                 # CSS/JS assets
├── docs/
│   ├── install-guide.md        # Full install documentation
│   ├── diagrams/               # Architecture diagrams
│   ├── hardware-guides/        # Hardware recommendations
│   ├── token-economy/          # SOV token whitepaper
│   └── key-mgmt/               # Key management best practices
├── poc/                        # Proof-of-concept scripts
│   ├── bootstrap.sh            # Quick-start POC
│   ├── proxmox-setup.sh        # Proxmox setup
│   ├── olares-vm.sh            # Olares VM deployment
│   ├── depin-compose.yml       # Sample DePIN Docker Compose
│   └── mesh-config/            # Mesh config templates
└── token/                      # SOV token implementation
    ├── programs/sov-token/     # Solana program (Rust)
    └── client/                 # TypeScript client library
```

---

## Roadmap

### v0.1.0 (Current — POC)
- [x] Project structure and documentation
- [x] POC bootstrap script (K3s + Olares)
- [x] DePIN container configs (Mysterium, Grass, Filecoin)
- [x] Mesh configs (Nebula, Netbird, Yggdrasil)
- [x] Basic SovereignNode dashboard (Flask)
- [x] SOV token (Solana program skeleton)

### v0.2.0 (Next — Beta)
- [ ] Full Proxmox integration with simplified UI
- [ ] One-click app installs in dashboard
- [ ] Automated SOV earning from DePIN nodes
- [ ] Distributed AI inference protocol
- [ ] Ansible fleet management playbooks
- [ ] Encrypted backup with key recovery

### v0.3.0 (Community Mesh)
- [ ] Meshtastic/LoRa integration
- [ ] LibreMesh Wi-Fi mesh firmware integration
- [ ] Off-grid operation mode (Tier 1 fallback)
- [ ] SOV staking and governance contracts

### v1.0.0 (Production)
- [ ] Certified hardware bundles
- [ ] App marketplace with SOV payments
- [ ] Multi-node HA clustering wizard
- [ ] Public SOV token launch

---

## Privacy & Sovereignty

SovereignNode is built on these principles:

1. **Your data never leaves your hardware** — No telemetry, no analytics unless you opt in.
2. **End-to-end encryption** — All backups are client-side encrypted before leaving your node.
3. **Key management** — Your encryption keys are yours; we provide tooling to back them up safely (Bitwarden-compatible, Syncthing for redundancy).
4. **Open source** — All SovereignNode code is MIT licensed. Underlying tools (Olares/AGPL, Proxmox/GPL, etc.) retain their licenses.
5. **DePIN opt-in** — Earning features are always opt-in. You choose what you share.

---

## Related Projects

SovereignNode builds on and integrates:

| Project | Role | License |
|---------|------|---------|
| [Olares](https://github.com/beclab/Olares) | Base OS, app runtime, UI inspiration | AGPL-3.0 |
| [Proxmox VE](https://proxmox.com) | Hypervisor, VM/container management | AGPL-3.0 |
| [K3s](https://k3s.io) | Lightweight Kubernetes | Apache-2.0 |
| [Ollama](https://ollama.ai) | Local LLM inference | MIT |
| [Nebula](https://github.com/slackhq/nebula) | Overlay mesh VPN | MIT |
| [Netbird](https://github.com/netbirdio/netbird) | WireGuard VPN mesh | BSD-3 |
| [Mysterium](https://github.com/mysteriumnetwork/node) | DePIN bandwidth | GPL-3.0 |
| [Home Assistant](https://home-assistant.io) | Smart home | Apache-2.0 |
| [Ansible](https://ansible.com) | Automation | GPL-3.0 |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). We welcome:
- Hardware compatibility reports and tier configs
- DePIN node integrations
- Dashboard improvements
- Documentation translations
- Bug fixes and security audits

---

## License

SovereignNode is MIT licensed. See [../LICENSE](../LICENSE).

Underlying components retain their respective open-source licenses.
