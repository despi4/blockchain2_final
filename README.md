# GameFi Economy — Blockchain Technologies 2 Final Project

**Option B — GameFi Economy**

A full-stack decentralized protocol featuring an ERC-1155 in-game item economy with crafting, AMM marketplace, NFT rental vault, Chainlink VRF loot drops, and DAO governance — deployed on Arbitrum Sepolia (L2).

---

## Deployed Contracts (Arbitrum Sepolia)

| Contract | Address | Explorer |
|---|---|---|
| GameFi Token (ERC20Votes) | `0x...` | [View](https://sepolia.arbiscan.io/address/0x...) |
| Game Items (ERC-1155) | `0x...` | [View](https://sepolia.arbiscan.io/address/0x...) |
| AMM | `0x...` | [View](https://sepolia.arbiscan.io/address/0x...) |
| Rental Vault (ERC-4626) | `0x...` | [View](https://sepolia.arbiscan.io/address/0x...) |
| Loot Drop (Chainlink VRF) | `0x...` | [View](https://sepolia.arbiscan.io/address/0x...) |
| Crafting | `0x...` | [View](https://sepolia.arbiscan.io/address/0x...) |
| **GameFiGovernor** | `0x...` | [View](https://sepolia.arbiscan.io/address/0x...) |
| **GameFiTimelock** | `0x...` | [View](https://sepolia.arbiscan.io/address/0x...) |

> Fill in after `forge script script/Deploy.s.sol --broadcast`.

---

## Architecture

```
User ──→ Frontend (React + Wagmi + RainbowKit)
           │
           ├── Dashboard:   Balance / Voting Power / Delegate / Recent Swaps
           ├── Items:        ERC-1155 Inventory / Crafting / VRF Loot Drop
           ├── Marketplace:  AMM Swap / Add Liquidity / ERC-4626 Vault Deposit
           └── Governance:   Propose / Vote / Queue / Execute
                                │
                         GameFiGovernor (OZ Governor)
                                │
                      GameFiTimelock (2-day delay)
                                │
                    ┌───────────┴─────────────┐
               Protocol Contracts          Treasury
             (AMM, Vault, Crafting,        (GFI tokens)
              LootDrop params)
```

### Design Patterns

| Pattern | Where Used | Justification |
|---|---|---|
| UUPS Proxy | AMM, Vault | Safe upgrade path without storage collision |
| Factory (CREATE2) | ItemFactory | Deterministic item contract addresses |
| Checks-Effects-Interactions | AMM, Vault, Crafting | Prevent reentrancy |
| Pull-over-Push | LootDrop | VRF callback is pull-based (no push ETH) |
| Access Control (Role-based) | All contracts | MINTER_ROLE, PAUSER_ROLE |
| Pausable / Circuit Breaker | AMM, Vault | Emergency stop via Timelock |
| Oracle adapter / interface | LootDrop, PriceFeed | Abstracts Chainlink behind interface |
| Timelock | GameFiTimelock | 2-day mandatory delay on governance actions |
| Reentrancy Guard | Vault, LootDrop | Defense-in-depth alongside CEI |
| State Machine | LootDrop | REQUESTED → FULFILLED → CLAIMED |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Smart Contracts | Solidity 0.8.24, Foundry |
| Token Standards | ERC-20 (ERC20Votes+Permit), ERC-1155, ERC-4626 |
| Oracle | Chainlink VRF v2.5, Chainlink Price Feeds |
| Governance | OpenZeppelin Governor + TimelockController |
| Indexing | The Graph (7 entities, 5 GraphQL queries) |
| Frontend | React 18 + Vite + Wagmi v2 + RainbowKit |
| L2 | Arbitrum Sepolia |
| CI | GitHub Actions + Slither + forge coverage |

---

## Governance Parameters

| Parameter | Value |
|---|---|
| Voting Delay | 7 200 blocks ≈ 1 day (at 12 s/block) |
| Voting Period | 50 400 blocks ≈ 1 week |
| Quorum | 4% of total supply |
| Proposal Threshold | 1% of total supply (10 000 GFI) |
| Timelock Delay | 2 days |

---

## Quick Start

```bash
# Prerequisites: Foundry, Node 20+
curl -L https://foundry.paradigm.xyz | bash && foundryup

git clone <repo> && cd blockchain2_final

# Contracts
forge install
cp .env.example .env   # fill PRIVATE_KEY, BASE_SEPOLIA_RPC_URL, BASESCAN_API_KEY

# Frontend
cd frontend && npm install && npm run dev
# → http://localhost:5173
```

### Run Tests

```bash
forge test -v                                    # all tests
forge test --match-path "test/governance/*" -v   # governance only
forge coverage --report summary                  # coverage report
```

### Deploy

```bash
export GOV_TOKEN_ADDRESS=0x...   # from Person 1's deployment
export PRIVATE_KEY=0x...

forge script script/Deploy.s.sol:Deploy \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast --verify \
  --etherscan-api-key $BASESCAN_API_KEY -vvvv
```

### Post-Deploy Verify

```bash
export GOVERNOR_ADDRESS=0x...
export TIMELOCK_ADDRESS=0x...

forge script script/PostDeployVerify.s.sol:PostDeployVerify \
  --rpc-url $BASE_SEPOLIA_RPC_URL -vvv
```

---

## Gas Comparison: Mainnet vs Arbitrum Sepolia

| Operation | Est. Gas | L1 Cost (30 gwei) | L2 Cost (0.001 gwei) | Savings |
|---|---|---|---|---|
| AMM swap | 110 000 | ~$6.60 | ~$0.00011 | ~60 000x |
| ERC-1155 mint | 60 000 | ~$3.60 | ~$0.00006 | ~60 000x |
| Vault deposit | 85 000 | ~$5.10 | ~$0.000085 | ~60 000x |
| Loot drop request | 95 000 | ~$5.70 | ~$0.000095 | ~60 000x |
| Craft item | 70 000 | ~$4.20 | ~$0.000070 | ~60 000x |
| Cast vote | 65 000 | ~$3.90 | ~$0.000065 | ~60 000x |

---

## Subgraph

The Graph URL: `https://api.studio.thegraph.com/query/YOUR_ID/gamefi-economy/version/latest`

Entities: `Swap`, `Proposal`, `Vote`, `TokenHolder`, `LootDrop`, `CraftingEvent`, `VaultDayData`

```bash
cd subgraph
graph auth --studio <deploy-key>
graph deploy --studio gamefi-economy
```

---

## Team

| Member | Area of Ownership |
|---|---|
| Person 1 | ERC-20/1155/4626 tokens · AMM · UUPS proxy · Factory · Chainlink adapters · Yul assembly · Tests |
| Person 2 | Governor + Timelock · Subgraph · Frontend · Deployment scripts · CI · Documentation |

---

## Documentation

- [Architecture Document](docs/architecture.md)
- [Security Audit Report](docs/audit-report.md)
- [Gas Optimization Report](docs/gas-report.md)
- [Coverage Report](coverage/coverage-report.md)
