// ── Contract addresses (fill in after deployment) ──────────────────────────
export const ADDRESSES = {
  GOVERNANCE_TOKEN: "0x0000000000000000000000000000000000000001",
  AMM:              "0x0000000000000000000000000000000000000002",
  VAULT:            "0x0000000000000000000000000000000000000003",
  GOVERNOR:         "0x0000000000000000000000000000000000000004",
  TIMELOCK:         "0x0000000000000000000000000000000000000005",
  ITEM_NFT:         "0x0000000000000000000000000000000000000006",
  LOOT:             "0x0000000000000000000000000000000000000007",
  CRAFTING:         "0x0000000000000000000000000000000000000008",
};

// ── ERC-1155 in-game items ────────────────────────────────────────────────────
export const ITEM_IDS = {
  1: { name: "Wood",          emoji: "🪵", type: "resource" },
  2: { name: "Iron",          emoji: "⚙️",  type: "resource" },
  3: { name: "Gold",          emoji: "🪙",  type: "resource" },
  4: { name: "Magic Essence", emoji: "✨",  type: "resource" },
  5: { name: "Iron Sword",    emoji: "⚔️",  type: "weapon",  recipe: [[2,3],[3,1]] },
  6: { name: "Gold Shield",   emoji: "🛡️",  type: "armor",   recipe: [[3,5],[2,2]] },
  7: { name: "Enchanted Staff",emoji:"🪄",  type: "weapon",  recipe: [[4,5],[1,3]] },
};

// ── Minimal ABIs (only functions used by the UI) ────────────────────────────
export const GOVERNANCE_TOKEN_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function getVotes(address) view returns (uint256)",
  "function delegates(address) view returns (address)",
  "function delegate(address delegatee)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
];

export const AMM_ABI = [
  "function getReserves() view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)",
  "function token0() view returns (address)",
  "function token1() view returns (address)",
  "function totalSupply() view returns (uint256)",
  "function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data)",
  "function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) view returns (uint256)",
  "function addLiquidity(uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address to) returns (uint256 liquidity)",
  "event Swap(address indexed sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out, address indexed to)",
];

export const VAULT_ABI = [
  "function totalAssets() view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function convertToAssets(uint256 shares) view returns (uint256)",
  "function deposit(uint256 assets, address receiver) returns (uint256 shares)",
  "function withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares)",
  "function maxDeposit(address) view returns (uint256)",
];

export const GOVERNOR_ABI = [
  "function state(uint256 proposalId) view returns (uint8)",
  "function proposalDeadline(uint256 proposalId) view returns (uint256)",
  "function proposalSnapshot(uint256 proposalId) view returns (uint256)",
  "function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)",
  "function hasVoted(uint256 proposalId, address account) view returns (bool)",
  "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
  "function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)",
  "function quorum(uint256 blockNumber) view returns (uint256)",
  "event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)",
];

// Proposal state enum (matches OpenZeppelin Governor)
export const PROPOSAL_STATE = {
  0: "Pending",
  1: "Active",
  2: "Canceled",
  3: "Defeated",
  4: "Succeeded",
  5: "Queued",
  6: "Expired",
  7: "Executed",
};

// ── ERC-1155 ABI ─────────────────────────────────────────────────────────────
export const ERC1155_ABI = [
  "function balanceOf(address account, uint256 id) view returns (uint256)",
  "function balanceOfBatch(address[] accounts, uint256[] ids) view returns (uint256[])",
  "function isApprovedForAll(address account, address operator) view returns (bool)",
  "function setApprovalForAll(address operator, bool approved)",
  "function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes data)",
];

// ── Crafting ABI ──────────────────────────────────────────────────────────────
export const CRAFTING_ABI = [
  "function craft(uint256[] calldata inputIds, uint256[] calldata inputAmounts, uint256 outputId) returns (uint256)",
  "function getCraftingCost(uint256 outputId) view returns (uint256[] inputIds, uint256[] inputAmounts)",
  "function craftingCostMultiplier() view returns (uint256)",
  "event ItemCrafted(indexed address crafter, uint256[] inputIds, uint256[] inputAmounts, uint256 outputId, uint256 outputAmount)",
];

// ── Loot Drop (VRF) ABI ────────────────────────────────────────────────────────
export const LOOT_ABI = [
  "function requestLootDrop() payable returns (uint256 requestId)",
  "function claimLoot(uint256 requestId)",
  "function pendingLoot(address user) view returns (uint256 requestId, bool fulfilled)",
  "function dropRate() view returns (uint256)",
  "function lootFee() view returns (uint256)",
  "event LootRequested(indexed address requester, indexed uint256 requestId)",
  "event LootFulfilled(indexed uint256 requestId, uint256[] randomWords, uint256[] itemIds)",
];

export const PROPOSAL_STATE_COLOR = {
  Pending:   "#f59e0b",
  Active:    "#3b82f6",
  Canceled:  "#6b7280",
  Defeated:  "#ef4444",
  Succeeded: "#10b981",
  Queued:    "#8b5cf6",
  Expired:   "#6b7280",
  Executed:  "#10b981",
};
