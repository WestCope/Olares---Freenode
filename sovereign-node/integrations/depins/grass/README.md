# Grass Network DePIN Integration

## Overview
[Grass](https://getgrass.io) is a decentralized residential proxy network where users earn GRASS tokens by sharing unused internet bandwidth.

## Requirements
- Residential IP (not datacenter/VPS — will be rejected)
- Active internet connection
- Account at https://getgrass.io

## Docker Setup

Grass originally used a browser extension. The community has created headless Docker implementations. Use the official extension in a browser-based container:

```bash
# Create your account at https://getgrass.io first
# Set credentials in your .env file:
# GRASS_USERNAME=your@email.com
# GRASS_PASSWORD=your-password

docker run -d \
  --name sn-grass \
  --restart unless-stopped \
  -e GRASS_USERNAME="${GRASS_USERNAME}" \
  -e GRASS_PASSWORD="${GRASS_PASSWORD}" \
  ghcr.io/sovereignnode/grass-node:latest
```

## Manual Browser Extension Method

If Docker is unavailable, install the Grass browser extension:
1. Install Chrome/Chromium
2. Add Grass extension from https://getgrass.io
3. Log in with your account
4. Keep browser running (use `Xvfb` for headless)

## Earnings
- Earn GRASS tokens based on uptime and bandwidth quality
- Expected: $5–20/month for typical residential connection
- Higher earnings in underserved regions

## References
- Website: https://getgrass.io
- Docs: https://docs.getgrass.io

> **Note**: SovereignNode does not officially endorse any specific DePIN.
> Always research risks before sharing bandwidth or resources.
