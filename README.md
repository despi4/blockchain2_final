# GameFi Economy - Blockchain Technologies 2 Final Project

This repository contains the full capstone implementation for a GameFi economy protocol.
It combines the core Solidity protocol, governance, frontend, deployment scripts, and subgraph work in one repo.

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
