# Mysterium Network DePIN Integration

## Overview
[Mysterium Network](https://mysterium.network) is a decentralized VPN network where node operators earn MYST tokens by providing bandwidth for VPN users.

## Prerequisites
- A residential IP address (not datacenter)
- Port 4449, 1194 (TCP/UDP), 4750 open in your firewall
- A crypto wallet (MetaMask, compatible with Polygon network)

## Quick Start

```bash
# Set your wallet address
export MYSTERIUM_WALLET="0xYourWalletAddress"

# Start the Mysterium node
docker compose up -d

# Access the setup wizard
xdg-open http://localhost:4449/ui
```

## Earnings
- Earnings depend on traffic routed through your node
- Payments in MYST tokens on Polygon network
- Expected: $5–30/month on typical residential connection
- Track earnings at: https://mystnodes.com

## References
- GitHub: https://github.com/mysteriumnetwork/node
- Docs: https://docs.mysterium.network/node-runners/
