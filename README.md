# GameFi Economy — Blockchain Technologies 2 Final Project

Option B. Two-person project: Person 1 built the core contracts (token, AMM, vault, loot, crafting), Person 2 (this repo) built the DAO governance layer, frontend, subgraph, and deployment tooling.

---

## What this project is

An on-chain GameFi economy where players trade resources, craft items, and earn loot drops — all governed by token holders through a DAO. The main idea is that game parameters (drop rates, crafting costs, fees) are not hardcoded; they go through a governance vote before any change takes effect.

The governance flow works like this:
- Anyone holding ≥ 1% of the token supply can submit a proposal
- Voting is open for ~1 week (50 400 blocks on Arbitrum)
- If 4% quorum is reached and For > Against, the proposal succeeds
- It then sits in a 2-day timelock before anyone can execute it

This means even if someone writes a malicious proposal, there's a 2-day window to notice before it runs.

---

## Project structure

```
blockchain2_final/
├── src/governance/
│   ├── GameFiGovernor.sol      # OpenZeppelin Governor with our settings
│   └── GameFiTimelock.sol      # 2-day timelock, self-governed
├── test/governance/
│   └── GovernorTest.t.sol      # 16 tests covering full proposal lifecycle
├── script/
│   ├── Deploy.s.sol            # deploys timelock + governor, wires roles
│   └── PostDeployVerify.s.sol  # sanity checks after deploy
├── subgraph/                   # The Graph indexing (7 entities)
├── frontend/                   # React + Wagmi v2 + RainbowKit v2
└── .github/workflows/ci.yml    # forge + slither + solhint + eslint
```

Person 1's contracts (token, AMM, vault, loot, crafting) live in a separate repo and are referenced by address.

---

## Governor parameters

| Parameter | Value | Reason |
|---|---|---|
| Voting delay | 7 200 blocks (~1 day) | gives token holders time to notice a proposal |
| Voting period | 50 400 blocks (~1 week) | enough time for participation |
| Quorum | 4% of total supply | reasonable threshold on a 1M token supply |
| Proposal threshold | 1% (10 000 GFI) | filters spam, doesn't block legitimate holders |
| Timelock delay | 2 days | window to react before execution |

Timelock is self-governed — the deployer gives up admin rights at deploy time. Only the governor can queue proposals.

---

## Running the tests

You need Foundry installed (`curl -L https://foundry.paradigm.xyz | bash`).

```bash
forge test -v
```

All 16 tests should pass. The test suite covers:

- Governor name, delay, period, quorum (unit)
- Proposal threshold enforcement
- Voting power after delegation
- No admin backdoor on timelock
- Full lifecycle: propose → vote → queue → execute
- Quorum not met → Defeated
- Double-vote reverts
- Against votes defeat proposal
- Fuzz: voting power matches delegated balance (1000 runs)

```bash
forge coverage --report summary
```

---

## Deploy (after Person 1 deploys their contracts)

Copy `.env.example` to `.env` and fill in your values. Never commit `.env`.

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ARBISCAN_API_KEY \
  -vvvv
```

Then verify the deployment came out right:

```bash
forge script script/PostDeployVerify.s.sol:PostDeployVerify \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
```

You should see `=== ALL CHECKS PASSED ===`.

After deploy, update the addresses in:
- `frontend/src/config/contracts.js`
- `subgraph/subgraph.yaml`

---

## Frontend

```bash
cd frontend
npm install
npm run dev
```

Open http://localhost:5173. Connect MetaMask on Arbitrum Sepolia. The app will prompt you to switch networks if you're on the wrong chain.

Pages:
- **Dashboard** — token balance, voting power, delegate, recent swaps from subgraph
- **Items** — ERC-1155 balances, VRF loot drops, crafting
- **Marketplace** — swap tokens, add liquidity, vault deposit
- **Governance** — browse proposals, cast votes, see state + vote counts

---

## Subgraph

The subgraph indexes 5 contract event streams into 7 GraphQL entities: Swap, Proposal, Vote, TokenHolder, LootDrop, CraftingEvent, VaultDayData.

Deploy to The Graph Studio after filling addresses in `subgraph/subgraph.yaml`:

```bash
cd subgraph
graph codegen && graph build
graph deploy --studio gamefi-economy
```

---

## Network

Deployed on **Arbitrum Sepolia** (chainId 421614). We picked Arbitrum over Ethereum mainnet or Base Sepolia because:
- we already had test ETH there
- L2 fees are low enough that governance transactions are practical for actual users
- Arbitrum has good Foundry + The Graph support

---

## CI

GitHub Actions runs on every push:
- `forge fmt --check` — formatting
- `forge build --sizes` — compilation
- `forge test --profile ci` — tests with 5000 fuzz runs
- `forge coverage` — coverage report uploaded as artifact
- Slither — static analysis, fails on high-severity findings
- Solhint — Solidity style linting
- ESLint + Prettier — frontend code quality
- `vite build` — production build check
