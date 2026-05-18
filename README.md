# GameFi Economy

[Presentation & Report](https://drive.google.com/drive/folders/1FOtnljXT3TvMyEYySqi-8ElUvIlJyRqN?usp=sharing)

GameFi Economy is a full-stack GameFi protocol built as a Blockchain Technologies 2 final project. The repository combines a Solidity protocol, DAO governance, a React frontend, deployment automation, and a The Graph indexing layer in one workspace.

The protocol models a small onchain game economy around:

- ERC20 resource tokens
- ERC1155 game items
- crafting
- AMM-based trading
- ERC4626 treasury yield vaults
- ERC1155 rentals
- VRF-style loot drops
- Chainlink-style price oracles
- DAO-controlled configuration and upgrades

## Arbitrum Sepolia Deployment

| Contract | Address | Explorer |
|---|---|---|
| GameGovernanceToken | 0x8c0af3d55Be9B86C3c74B3c706Fc38409A703D20 | [view](https://sepolia.arbiscan.io/address/0x8c0af3d55Be9B86C3c74B3c706Fc38409A703D20) |
| GoldToken | 0xE3De34EBB28493b5D8F59ba7BB07e21a25f8AdAb | [view](https://sepolia.arbiscan.io/address/0xE3De34EBB28493b5D8F59ba7BB07e21a25f8AdAb) |
| IronToken | 0x5A63d721CE3b0dcAAF230c685A4A992666D528e9 | [view](https://sepolia.arbiscan.io/address/0x5A63d721CE3b0dcAAF230c685A4A992666D528e9) |
| WoodToken | 0xf5Fe7C3c8820a459a16AfE810B92c147ab91457b | [view](https://sepolia.arbiscan.io/address/0xf5Fe7C3c8820a459a16AfE810B92c147ab91457b) |
| GameItems (ERC1155) | 0xf16454c6f28694a291bEADb0658Df1A95419B712 | [view](https://sepolia.arbiscan.io/address/0xf16454c6f28694a291bEADb0658Df1A95419B712) |
| CraftingSystem | 0x393825Ac24DAcF19616b46F7C5eafa415BEB5424 | [view](https://sepolia.arbiscan.io/address/0x393825Ac24DAcF19616b46F7C5eafa415BEB5424) |
| ResourceAMM (GOLD/IRON) | 0x1f35Ec70fcF576ef585fF923F9479df54427fa98 | [view](https://sepolia.arbiscan.io/address/0x1f35Ec70fcF576ef585fF923F9479df54427fa98) |
| GuildTreasuryVault (proxy) | 0xbb2db02389cB4C90956FCb9018f04fe96d51D502 | [view](https://sepolia.arbiscan.io/address/0xbb2db02389cB4C90956FCb9018f04fe96d51D502) |
| ItemRentalVault | 0x1e7CBF8C16654AdA9D74b83F1c0E9c25310142dc | [view](https://sepolia.arbiscan.io/address/0x1e7CBF8C16654AdA9D74b83F1c0E9c25310142dc) |
| LootDrop | 0x586d17959de7585A9eD06C34288f2C1Eb7854093 | [view](https://sepolia.arbiscan.io/address/0x586d17959de7585A9eD06C34288f2C1Eb7854093) |
| PriceOracle | 0x80a01232F572960b5aB853162A8A09D12D79Ce40 | [view](https://sepolia.arbiscan.io/address/0x80a01232F572960b5aB853162A8A09D12D79Ce40) |
| GameConfig (proxy) | 0xb07Ff42844Fd8372465ED91Fa47E3317410Fc0F2 | [view](https://sepolia.arbiscan.io/address/0xb07Ff42844Fd8372465ED91Fa47E3317410Fc0F2) |
| GameFactory | 0x5AE532c9C4c37Adc1d6fCAC61A5761A3c6AbC96B | [view](https://sepolia.arbiscan.io/address/0x5AE532c9C4c37Adc1d6fCAC61A5761A3c6AbC96B) |
| GameFiGovernor | 0xEd011c6397B2BEB7f2cc43892C492604165bBAdB | [view](https://sepolia.arbiscan.io/address/0xEd011c6397B2BEB7f2cc43892C492604165bBAdB) |
| GameFiTimelock | 0x73D39aD3D837b68e31c6a800b5732e3FBCe5b7bC | [view](https://sepolia.arbiscan.io/address/0x73D39aD3D837b68e31c6a800b5732e3FBCe5b7bC) |

The canonical target network for the repo is `Arbitrum Sepolia`.

## Highlights

- `GameGovernanceToken` implements `ERC20Votes` and `ERC20Permit`
- `GameItems` implements ERC1155-based in-game items
- `ResourceAMM` provides a constant-product `x * y = k` pool with a 0.3% swap fee and LP token
- `GuildTreasuryVault` provides an upgradeable ERC4626 treasury vault
- `CraftingSystem` burns item inputs and mints crafted outputs
- `ItemRentalVault` supports custodial ERC1155 rentals paid in `GoldToken`
- `LootDrop` follows a production-style VRF request/fulfill flow with a deterministic mock coordinator for tests
- `PriceOracle` wraps a Chainlink-style feed with stale-price protection
- `GameConfigV1` and `GameConfigV2` demonstrate UUPS upgrades
- `GameFactory` demonstrates both `CREATE` and `CREATE2`
- `GameMathYul` benchmarks inline Yul against a pure Solidity equivalent
- `GameFiGovernor` and `GameFiTimelock` provide DAO governance and delayed execution

## Current Status

The Solidity protocol is implemented and heavily tested.

- `184` tests passing
- unit, fuzz, invariant, fork, and security-focused tests included
- line coverage above `90%`
- deployment, frontend wiring, and subgraph wiring scripts are included

## Architecture

### Core protocol flow

1. Players hold `GoldToken`, `IronToken`, `WoodToken`, and `GameItems`.
2. They trade resource tokens through `ResourceAMM`.
3. They craft ERC1155 items through `CraftingSystem`.
4. They can list ERC1155 items in `ItemRentalVault` and collect rental income in `GoldToken`.
5. They can request loot drops through `LootDrop`, which mints rewards after randomness fulfillment.
6. The protocol treasury is modeled as an upgradeable ERC4626 vault.
7. Governance token holders can propose, vote, queue, and execute DAO actions through the governor plus timelock stack.
8. Protocol parameters are held in an upgradeable config contract to demonstrate safe UUPS upgrades.

### Governance model

The DAO stack is built around:

- [GameGovernanceToken](src/token/GameGovernanceToken.sol)
- [GameFiGovernor](src/governance/GameFiGovernor.sol)
- [GameFiTimelock](src/governance/GameFiTimelock.sol)

This gives the protocol:

- delegated voting power
- proposal thresholds
- quorum enforcement
- delayed execution through timelock
- transfer of admin and ownership rights away from the deployer

### Upgrade model

The repo contains two UUPS examples:

- [GameConfigV1.sol](src/upgrade/GameConfigV1.sol)
- [GameConfigV2.sol](src/upgrade/GameConfigV2.sol)

The treasury vault is also deployed behind an `ERC1967Proxy`, which demonstrates upgradeable storage layout discipline and proxy-based initialization.

## Smart Contracts

### Tokens and items

| Contract | Purpose |
|---|---|
| [GameGovernanceToken.sol](src/token/GameGovernanceToken.sol) | Governance token with voting and permit support |
| [GoldToken.sol](src/token/GoldToken.sol) | Primary ERC20 economy token used in loot and rentals |
| [IronToken.sol](src/token/IronToken.sol) | Resource ERC20 token |
| [WoodToken.sol](src/token/WoodToken.sol) | Resource ERC20 token |
| [ResourceToken.sol](src/token/ResourceToken.sol) | Generic role-gated resource token base |
| [GameItems.sol](src/token/GameItems.sol) | ERC1155 collection for in-game items |
| [ItemRegistry.sol](src/token/ItemRegistry.sol) | Supplemental item configuration registry |

### Trading and vaults

| Contract | Purpose |
|---|---|
| [ResourceAMM.sol](src/amm/ResourceAMM.sol) | Constant-product AMM for resource-token trading |
| [ResourceLPToken.sol](src/amm/ResourceLPToken.sol) | LP token minted by the AMM |
| [GuildTreasuryVaultV1.sol](src/vault/GuildTreasuryVaultV1.sol) | Upgradeable ERC4626 treasury vault |
| [GuildTreasuryVaultV2.sol](src/vault/GuildTreasuryVaultV2.sol) | Extended vault version with more controls |
| [ItemRentalVault.sol](src/vault/ItemRentalVault.sol) | ERC1155 rental marketplace with escrowed custody |
| [RentalEscrow.sol](src/vault/RentalEscrow.sol) | Native token escrow helper used in support flows |

### Gameplay systems

| Contract | Purpose |
|---|---|
| [CraftingSystem.sol](src/crafting/CraftingSystem.sol) | Burns crafting inputs and mints outputs |
| [LootDrop.sol](src/loot/LootDrop.sol) | Randomness-backed loot drop logic |
| [MockLootVRFCoordinator.sol](src/loot/mocks/MockLootVRFCoordinator.sol) | Deterministic VRF mock for tests and testnet-style demos |

### Oracle, config, factory, math

| Contract | Purpose |
|---|---|
| [PriceOracle.sol](src/oracle/PriceOracle.sol) | Chainlink-style oracle wrapper with staleness checks |
| [MockV3Aggregator.sol](src/oracle/mocks/MockV3Aggregator.sol) | Mock price feed for tests |
| [GameConfigV1.sol](src/upgrade/GameConfigV1.sol) | UUPS upgradeable protocol config |
| [GameConfigV2.sol](src/upgrade/GameConfigV2.sol) | V2 config preserving storage and adding new state |
| [GameFactory.sol](src/factory/GameFactory.sol) | Factory using both `CREATE` and `CREATE2` |
| [DeterministicAddressLib.sol](src/factory/DeterministicAddressLib.sol) | Deterministic deployment address helpers |
| [GameMath.sol](src/math/GameMath.sol) | Pure Solidity math reference implementation |
| [GameMathYul.sol](src/math/GameMathYul.sol) | Inline Yul benchmark implementation |
| [CraftingMath.sol](src/math/CraftingMath.sol) | Math helpers for crafting logic |
| [ResourceMath.sol](src/math/ResourceMath.sol) | Math helpers for AMM and resource calculations |

### Governance and admin

| Contract | Purpose |
|---|---|
| [GameFiGovernor.sol](src/governance/GameFiGovernor.sol) | Main OZ-based governor |
| [GameFiTimelock.sol](src/governance/GameFiTimelock.sol) | Timelock for delayed governance execution |
| [GameGovernor.sol](src/governance/GameGovernor.sol) | Alternate governor implementation kept for reference/testing |
| [ProtocolTimelock.sol](src/governance/ProtocolTimelock.sol) | Alternate timelock implementation |
| [ProtocolConfig.sol](src/governance/ProtocolConfig.sol) | Additional governance-controlled config surface used in tests |
| [GovernanceActions.sol](src/governance/GovernanceActions.sol) | Helper target for governance action tests |

## Repository Layout

| Path | Contents |
|---|---|
| `src/` | Solidity protocol contracts |
| `test/` | Unit, fuzz, invariant, fork, and security tests |
| `script/` | Deployment, verification, and sync scripts |
| `frontend/` | React + Vite frontend |
| `subgraph/` | The Graph indexing project |
| `deployments/` | Network-specific deployment manifests |
| `docs/` | Reports and generated output such as gas snapshots |

## Frontend

The frontend is a React application built with Vite and Wagmi/RainbowKit.

Pages currently present:

- [Home.jsx](frontend/src/pages/Home.jsx)
- [Items.jsx](frontend/src/pages/Items.jsx)
- [Marketplace.jsx](frontend/src/pages/Marketplace.jsx)
- [Vault.jsx](frontend/src/pages/Vault.jsx)
- [Rental.jsx](frontend/src/pages/Rental.jsx)
- [Loot.jsx](frontend/src/pages/Loot.jsx)
- [Governance.jsx](frontend/src/pages/Governance.jsx)
- [Subgraph.jsx](frontend/src/pages/Subgraph.jsx)

Frontend responsibilities:

- wallet connect
- wrong-network detection
- balances and dashboard views
- AMM interaction
- crafting flow
- vault deposit and withdraw flow
- rental interaction
- loot interaction
- proposal and voting views
- indexed data views from the subgraph

## Subgraph

The subgraph indexes protocol activity for the frontend and analytics workflows.

Indexed domains include:

- swaps
- loot drops
- crafting
- treasury vault activity
- rentals
- governance activity

Important files:

- [subgraph/schema.graphql](subgraph/schema.graphql)
- [subgraph/subgraph.template.yaml](subgraph/subgraph.template.yaml)
- [subgraph/subgraph.yaml](subgraph/subgraph.yaml)
- `subgraph/abis/`
- `subgraph/src/`

## Local Development

### Requirements

- Foundry
- Node.js 18+
- npm
- Git

### Clone and install

```bash
git clone <your-repo-url>
cd blockchain2_final
git submodule update --init --recursive
```

Install frontend dependencies:

```bash
cd frontend
npm install
cd ..
```

Install subgraph dependencies:

```bash
cd subgraph
npm install
cd ..
```

### Environment setup

Copy the root env template:

```bash
cp .env.example .env
```

Important root env variables:

- `PRIVATE_KEY`
- `ARBITRUM_SEPOLIA_RPC_URL`
- `ARBISCAN_API_KEY`
- `WALLETCONNECT_PROJECT_ID`
- `VITE_SUBGRAPH_URL`

The frontend also has its own template:

```bash
cp frontend/.env.example frontend/.env.local
```

After a deployment, do not hand-edit frontend addresses unless you need to. Instead, update the deployment manifest and run the sync script.

## Build and Test

### Foundry

Build contracts:

```bash
forge build
```

Run all tests:

```bash
forge test
```

Run coverage:

```bash
forge coverage --report summary
```

Run a specific test file:

```bash
forge test --match-path test/unit/ResourceAMM.t.sol -vv
```

Run only invariant tests:

```bash
forge test --match-path "test/invariant/*.t.sol"
```

### Frontend

```bash
cd frontend
npm run dev
```

Build the frontend:

```bash
cd frontend
npm run build
```

Lint the frontend:

```bash
cd frontend
npm run lint
```

### Subgraph

Generate types:

```bash
cd subgraph
npm run codegen
```

Build the subgraph:

```bash
cd subgraph
npm run build
```

## Test Suite

The test suite is split into multiple categories so the repo covers both correctness and security expectations.

### Unit tests

Examples:

- AMM behavior
- ERC20 and ERC1155 permissions
- crafting recipes
- loot drop flows
- oracle stale checks
- config upgrades
- vault edge cases

### Fuzz tests

Examples:

- AMM swap and liquidity invariants under varied inputs
- vault deposit and withdraw behavior
- rental duration behavior
- game logic parameter fuzzing
- Yul-vs-Solidity output parity

### Invariant tests

Examples:

- AMM invariant preservation
- rental custody accounting
- vault share backing
- broader system invariants across items and rentals

### Fork tests

Examples:

- Chainlink feed reads
- ERC20 metadata reads
- deployed governance parameter checks

### Security tests

Examples:

- before/after reentrancy demonstration
- before/after access-control demonstration

## Deployment

The deployment flow is centered on `Arbitrum Sepolia`.

### Root deployment script

Main deploy script:

- [script/Deploy.s.sol](script/Deploy.s.sol)

This script deploys the full protocol stack, including:

- governance token
- resource tokens
- ERC1155 items
- crafting system
- mock VRF coordinator
- loot drop
- item rental vault
- upgradeable treasury vault proxy
- upgradeable config proxy
- AMM
- factory
- mock price feed
- price oracle
- Yul benchmark contract
- timelock
- governor

### Bash deployment command

```bash
source .env
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$ARBITRUM_SEPOLIA_RPC_URL" \
  --broadcast \
  --verify \
  --etherscan-api-key "$ARBISCAN_API_KEY" \
  -vvvv
```

### PowerShell deployment command

```powershell
& "$env:USERPROFILE\.foundry\bin\forge.exe" script script/Deploy.s.sol:Deploy `
  --rpc-url $env:ARBITRUM_SEPOLIA_RPC_URL `
  --broadcast `
  --verify `
  --etherscan-api-key $env:ARBISCAN_API_KEY `
  -vvvv
```

### Deployment manifest

Deployment data is tracked in:

- [deployments/arbitrum-sepolia.json](deployments/arbitrum-sepolia.json)

For frontend and subgraph sync, the canonical manifest shape is documented in:

- [deployments/arbitrum-sepolia.example.json](deployments/arbitrum-sepolia.example.json)

If your deployment output does not already match the example structure, normalize the addresses and `startBlocks` into the example format before running the sync script.

### Sync frontend and subgraph config

After deployment:

```bash
node script/syncDeploymentConfig.mjs
```

This writes:

- `frontend/.env.local`
- `subgraph/subgraph.yaml`

based on the canonical manifest format in:

- [deployments/arbitrum-sepolia.json](deployments/arbitrum-sepolia.json)

### Post-deploy verification

Verification script:

- [script/PostDeployVerify.s.sol](script/PostDeployVerify.s.sol)

Example:

```bash
forge script script/PostDeployVerify.s.sol:PostDeployVerify \
  --rpc-url "$ARBITRUM_SEPOLIA_RPC_URL" \
  -vvv
```

## Arbitrum Sepolia Addresses

The repo currently tracks these deployed addresses:

| Contract | Address |
|---|---|
| GameGovernanceToken | `0x313a07eD2D5E3313842ABB36758ab9cf1D76c0fB` |
| GoldToken | `0x14378a2c508E02D92F431E84C6dBCa31Cdbff189` |
| IronToken | `0x0721349628E0C66489D64Eb4abBa20D1648B99F9` |
| WoodToken | `0xBe435a8a357c6a20388900C29d0cd5091a5aE114` |
| GameItems | `0x80a782F1f3549850d157cb09d60762B3507C338A` |
| CraftingSystem | `0x4ad419cDfbe2283938279965F3065D45a80f137E` |
| ResourceAMM | `0xA2be842a973205D40Df5782089ae35d5F60c86ce` |
| GuildTreasuryVault proxy | `0x8Fb7D764a078266785Ab1a69cFBAB61BAe42dC5b` |
| ItemRentalVault | `0x3f230808AFAAed9A960485517b2bCbe10A51EeEd` |
| LootDrop | `0x5a545d790b4f6Ed9c5B35463F308eA71c11820Ff` |
| PriceOracle | `0xC0332BCA5b3D2f92cD444C32Cf73A150055c38fD` |
| GameConfig proxy | `0x33579c409D2ddAE85A601034233b53FcC671026C` |
| GameFactory | `0x8859a9dc6F0F45A6077424d2da0bcbFE3823855e` |
| GameFiGovernor | `0x6e35c59EA9458c9c61B16FA2f9e5Dece0ffF813c` |
| GameFiTimelock | `0x7D01CeAe7d71439a75e698D9e880213e1Aed7B4E` |

If these addresses change, update the deployment manifest and regenerate frontend and subgraph config with the sync script instead of manually editing multiple files.

## Governance Parameters

Current governance settings:

| Parameter | Value |
|---|---|
| Voting delay | `7,200` blocks, roughly 1 day |
| Voting period | `50,400` blocks, roughly 1 week |
| Quorum | `4%` of total supply |
| Proposal threshold | `10,000 gGAME`, roughly 1% of 1M initial supply |
| Timelock delay | `2 days` |

## Security Notes

The protocol was built with a security-first capstone mindset:

- `ReentrancyGuard` is used where stateful external interactions need protection
- `SafeERC20` is used for ERC20 payment flows
- AMM functions include slippage protection
- price reads reject stale data
- upgradeability uses OZ patterns with protected authorization
- tests include explicit before/after exploit demonstrations

This repo is still a student project, not a production deployment. It should be treated as an educational implementation unless independently audited and hardened further.

## Known Notes

- The repo contains both canonical contracts and some alternate governance/reference contracts kept for testing and comparison.
- Testnet randomness and oracle integrations use mocks where appropriate so the flows remain deterministic in tests.
- The frontend and subgraph are designed to be driven by the deployment manifest rather than scattered hardcoded addresses.
- On Windows PowerShell, environment variables must be referenced as `$env:VARIABLE_NAME`.

## Useful Commands

### Full local Solidity check

```bash
forge build && forge test && forge coverage --report summary
```

### Frontend build check

```bash
cd frontend && npm run build && npm run lint
```

### Subgraph build check

```bash
cd subgraph && npm run codegen && npm run build
```

## License

This project is provided for educational use as part of a blockchain engineering final project.
