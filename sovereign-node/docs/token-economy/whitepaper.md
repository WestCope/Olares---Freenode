# SOV Token Economy Whitepaper v0.1

## Abstract

SovereignNode introduces the **SOV token** — a utility token on Solana that creates economic incentives for operating, contributing to, and using the SovereignNode network. SOV enables node operators to earn from DePIN contributions (bandwidth, storage, compute), pay for services (AI inference, storage), stake for governance, and participate in the decentralized resource marketplace.

---

## 1. Network Participants

### 1.1 Node Operators (Earners)
- Run SovereignNode software on home hardware
- Contribute resources: bandwidth, storage, compute, AI inference
- Earn SOV tokens proportional to contribution quality and quantity
- Tiered multipliers incentivize hardware upgrades

### 1.2 Resource Consumers (Spenders)
- Use the network for AI inference, extra storage, bandwidth
- Pay in SOV tokens at market rates
- Benefit from decentralized, censorship-resistant services

### 1.3 Stakers (Governors)
- Lock SOV tokens in the staking contract
- Receive governance voting power
- Higher reward multipliers (up to 2.5×)
- Vote on fee structures, feature priorities, treasury allocation

### 1.4 Developers (Builders)
- Deploy apps in the SovereignNode marketplace
- List services, earn SOV for usage
- Governance for new app categories

---

## 2. Token Supply & Distribution

**Total Supply: 1,000,000,000 SOV** (1 billion, fixed, non-inflationary after launch)

| Allocation | % | Amount | Vesting |
|-----------|---|--------|---------|
| Node Rewards Pool | 40% | 400M SOV | Released over 10 years |
| Treasury | 20% | 200M SOV | Controlled by governance |
| Community/Airdrops | 15% | 150M SOV | Early node operators |
| Staking Rewards | 15% | 150M SOV | Released over 5 years |
| Team & Advisors | 10% | 100M SOV | 1yr cliff, 4yr vesting |

### Emission Schedule
- Year 1: 100M SOV released (25% of rewards pool)
- Year 2: 80M SOV (halving-like reduction)
- Years 3-10: 27.5M SOV/year
- Post year 10: Network fees only (no new emissions)

---

## 3. Earning Mechanisms

### 3.1 DePIN Contribution Rewards

| Resource | Unit | Base Rate | Tier Multiplier |
|----------|------|-----------|----------------|
| Bandwidth | per 1 GB proxied | 1 SOV | Min: 1×, Med: 2×, Max: 5× |
| Storage | per GB/month | 10 SOV | Min: 1×, Med: 1.5×, Max: 3× |
| CPU compute | per compute unit | 100 SOV | Min: 1×, Med: 2×, Max: 4× |
| GPU compute | per GPU-hour | 1,000 SOV | Max only: 10× |
| AI inference | per 1M tokens | 500 SOV | Varies by model |

Contribution points accumulate on-chain and are claimable as SOV tokens.

### 3.2 Uptime Bonuses
- 99%+ uptime: +20% reward bonus
- 95–99% uptime: +10% reward bonus
- <90% uptime: No bonus, possible slashing (future)

### 3.3 Staking Yield
Active stakers receive a share of network fees:
- 50% of all SOV payments go to the staking pool
- Distributed proportionally to stake weight
- Estimated APY: 8–15% depending on network utilization

---

## 4. Spending Mechanisms

### 4.1 AI Inference Marketplace
Low-power nodes request AI jobs from high-power nodes:
- Price set by supply/demand
- Escrow via smart contract
- Payment released on job completion and validation

### 4.2 Storage Marketplace
- Rent storage from other nodes
- Guaranteed by cryptographic proofs (Filecoin-inspired)
- Payments stream per hour of storage

### 4.3 App Marketplace
- Developers list apps for SOV
- 80% to developer, 10% to treasury, 10% burned
- SOV burn creates deflationary pressure over time

---

## 5. Governance

SOV stakers vote on:
- Network fee structures
- New feature priorities
- Treasury allocations
- Emergency upgrades

**Voting power**: 1 SOV staked = 1 vote
**Quorum**: 10% of staked supply
**Proposal threshold**: 10,000 SOV staked to create proposal

---

## 6. Security & Audits

- Smart contracts written in Rust (Anchor framework)
- PDAs hold all funds (no EOA custody)
- Formal audit before mainnet launch
- Bug bounty program on launch

---

## 7. Roadmap

| Phase | Milestone | SOV Events |
|-------|-----------|-----------|
| Q2 2025 | Devnet launch | Testnet SOV (no value) |
| Q3 2025 | Mainnet launch | Community airdrop (early operators) |
| Q4 2025 | DEX listing | Raydium/Orca liquidity |
| Q1 2026 | Governance live | Treasury votes begin |
| Q2 2026 | Compute marketplace | AI inference payments |
| 2027+ | Cross-chain bridge | ETH/BSC interoperability |

---

*This whitepaper describes the intended design. SOV token has no expected economic value. Participating in DePIN networks involves risk. Always research before contributing resources.*
