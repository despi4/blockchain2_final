# GameFi Economy - Blockchain Technologies 2 Final Project

This repository contains the full capstone implementation for a GameFi economy protocol.
It combines the core Solidity protocol, governance, frontend, deployment scripts, and subgraph work in one repo.

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
