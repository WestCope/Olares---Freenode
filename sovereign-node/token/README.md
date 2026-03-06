# SOV Token — SovereignNode Network Utility Token

## Overview

The `SOV` token is a Solana-based utility token that powers the SovereignNode network economy.

## Tokenomics

| Category | Allocation | Tokens |
|----------|-----------|--------|
| **Node Rewards** (DePIN earning) | 40% | 400,000,000 SOV |
| **Treasury / Development** | 20% | 200,000,000 SOV |
| **Community / Airdrops** | 15% | 150,000,000 SOV |
| **Staking Rewards** | 15% | 150,000,000 SOV |
| **Team / Advisors** (4yr vest) | 10% | 100,000,000 SOV |
| **Total Supply** | 100% | **1,000,000,000 SOV** |

## Earning SOV

Nodes earn SOV by contributing resources to the network:

| Contribution | SOV Rate | Multiplier |
|-------------|---------|------------|
| Bandwidth sharing | 1 SOV / GB | Tier 1: 1×, Tier 2: 2×, Tier 3: 5× |
| Storage provision | 10 SOV / GB/month | |
| Compute (CPU/hr) | 100 SOV / unit | |
| AI inference | Market rate | |

## Spending SOV

- **AI compute** — Pay Tier 3 nodes for large model inference
- **Premium storage** — Rent extra Filecoin storage
- **Priority queue** — Skip the queue for compute jobs
- **App marketplace** — Purchase premium apps

## Staking

Staking SOV provides:
- Governance voting rights (1 SOV = 1 vote)
- Higher reward multipliers
- Priority compute access
- Network proposals

Minimum stake: 1,000 SOV for governance participation.

## Smart Contract

The Solana program is in [`programs/sov-token/src/lib.rs`](programs/sov-token/src/lib.rs).

Built with [Anchor framework](https://www.anchor-lang.com/).

### Build & Test

```bash
# Install Anchor CLI
cargo install --git https://github.com/coral-xyz/anchor avm --locked
avm install latest && avm use latest

# Build
cd token
anchor build

# Test
anchor test

# Deploy to devnet
anchor deploy --provider.cluster devnet
```

## Client Usage (TypeScript)

```typescript
import { SovTokenClient } from './client/sov-token-client';
import { Connection, Keypair } from '@solana/web3.js';

const connection = new Connection('https://api.devnet.solana.com');
const wallet = Keypair.fromSecretKey(/* your keypair */);
const client = new SovTokenClient(connection, wallet);

// Register your node
await client.registerNode(NodeTier.Min);

// Claim accumulated rewards
const claimed = await client.claimRewards();
console.log(`Claimed ${claimed} SOV`);

// Stake for governance
await client.stake(1000_000_000_000n); // 1000 SOV (9 decimals)
```

## Security

- All funds are held in program-derived addresses (PDAs)
- No admin upgrade key after initial deployment
- Audited by [TODO: security audit]
- Open source under MIT license

## Roadmap

- [x] SOV token program (Solana/Anchor)
- [x] Node registration and tier system
- [x] Contribution recording and reward accrual
- [x] Staking for governance
- [x] Compute payment channel
- [ ] On-chain governance voting
- [ ] DEX liquidity (Raydium/Orca)
- [ ] Public sale / community distribution
- [ ] Cross-chain bridge (Ethereum/BSC)
