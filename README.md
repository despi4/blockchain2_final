# GameFi Economy - Blockchain Technologies 2 Final Project

This repository contains the full capstone implementation for a GameFi economy protocol.
It combines the core Solidity protocol, governance, frontend, deployment scripts, and subgraph work in one repo.

## Arbitrum Sepolia Deployment

> **Fill in after running `forge script script/Deploy.s.sol:Deploy --broadcast`.**
> The deploy script writes real addresses to `deployments/arbitrum-sepolia.json` automatically.

| Contract | Address | Explorer |
|---|---|---|
| GameGovernanceToken | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| GoldToken | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| IronToken | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| WoodToken | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| GameItems (ERC1155) | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| CraftingSystem | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| ResourceAMM (GOLD/IRON) | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| GuildTreasuryVault (proxy) | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| ItemRentalVault | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| LootDrop | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| PriceOracle | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| GameConfig (proxy) | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| GameFactory | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| GameFiGovernor | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |
| GameFiTimelock | 0x0000000000000000000000000000000000000000 | [view](https://sepolia.arbiscan.io/address/0x0000000000000000000000000000000000000000) |

### Deploy command

```bash
# 1. Copy env template and fill in PRIVATE_KEY, ARBITRUM_SEPOLIA_RPC_URL, ARBISCAN_API_KEY
cp .env.example .env

# 2. Deploy all contracts, verify on Arbiscan, write deployments/arbitrum-sepolia.json
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ARBISCAN_API_KEY \
  -vvvv

# 3. Sync addresses to frontend/.env.local and subgraph/subgraph.yaml
node script/syncDeploymentConfig.mjs

# 4. Verify post-deployment invariants
forge script script/PostDeployVerify.s.sol:PostDeployVerify \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  -vvv
```

### Governance parameters

| Parameter | Value |
|---|---|
| Voting delay | 7 200 blocks (~1 day) |
| Voting period | 50 400 blocks (~1 week) |
| Quorum | 4% of total supply |
| Proposal threshold | 10 000 gGAME (1% of 1 M supply) |
| Timelock delay | 2 days |

---

## Canonical testnet

The repo is now aligned around `Arbitrum Sepolia` as the default L2 target:

- frontend wallet config targets `Arbitrum Sepolia`
- subgraph sources target `arbitrum-sepolia`
- `.env.example` uses `ARBITRUM_SEPOLIA_RPC_URL` and `ARBISCAN_API_KEY`
- deployment placeholders live in [deployments/arbitrum-sepolia.example.json](deployments/arbitrum-sepolia.example.json)

## Main modules

- `src/token/` - governance token, resource tokens, ERC1155 game items
- `src/amm/` - constant-product AMM and LP token
- `src/vault/` - rental vault and upgradeable treasury vault
- `src/crafting/` - crafting logic for burning resources and minting items
- `src/loot/` - VRF-style loot drop flow
- `src/oracle/` - Chainlink-style price feed wrapper with staleness checks
- `src/upgrade/` - UUPS upgradeable config contracts
- `src/governance/` - governor and timelock contracts
- `frontend/` - React frontend
- `subgraph/` - The Graph indexing layer
- `script/` - deployment and verification scripts

## Governance

The governance layer is built around a Governor plus Timelock setup so DAO-controlled parameters can be updated onchain.
This includes fee parameters, crafting controls, loot configuration, and upgrade authority.

## Frontend

The frontend provides wallet connectivity, network checks, and protocol-facing pages for governance, items, marketplace flows, and related views.

## Subgraph

The subgraph indexes protocol activity such as swaps, crafting, loot, and governance activity for UI consumption.

## Foundry

Build:

```bash
forge build
```

Test:

```bash
forge test
```

Coverage:

```bash
forge coverage --report summary
```

## Frontend local run

```bash
cd frontend
npm install
npm run dev
```

Frontend addresses are read from `frontend/.env.local`. Start from [frontend/.env.example](frontend/.env.example) and fill in the deployed addresses.

## Subgraph wiring

The subgraph now indexes the canonical contracts and real event signatures for:

- `ResourceAMM`
- `GameFiGovernor`
- `GameGovernanceToken`
- `LootDrop`
- `CraftingSystem`
- `GuildTreasuryVaultV1`
- `ItemRentalVault`

Before deploying the subgraph:

1. Copy real addresses and `startBlock` values into `deployments/arbitrum-sepolia.json` or patch [subgraph/subgraph.yaml](subgraph/subgraph.yaml) directly
2. Keep the ABI files in `subgraph/abis/` in sync with `forge build`
3. Set `VITE_SUBGRAPH_URL` in the frontend after the Graph deployment is live

To avoid editing the frontend and subgraph by hand every time, copy [deployments/arbitrum-sepolia.example.json](deployments/arbitrum-sepolia.example.json) to `deployments/arbitrum-sepolia.json`, fill in the deployed addresses, and run:

```bash
node script/syncDeploymentConfig.mjs
```

That command writes:

- `frontend/.env.local`
- `subgraph/subgraph.yaml`

Local subgraph build:

```bash
cd subgraph
npm install
npm run codegen
npm run build
```
