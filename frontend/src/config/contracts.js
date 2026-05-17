const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

function envAddress(name, fallback = ZERO_ADDRESS) {
  return import.meta.env[name] || fallback;
}

export const ADDRESSES = {
  GOVERNANCE_TOKEN: envAddress(
    "VITE_GOVERNANCE_TOKEN_ADDRESS",
    "0x0000000000000000000000000000000000000001"
  ),
  GOLD_TOKEN: envAddress("VITE_GOLD_TOKEN_ADDRESS", "0x0000000000000000000000000000000000000002"),
  AMM: envAddress("VITE_AMM_ADDRESS", "0x0000000000000000000000000000000000000003"),
  VAULT: envAddress("VITE_VAULT_ADDRESS", "0x0000000000000000000000000000000000000004"),
  GOVERNOR: envAddress("VITE_GOVERNOR_ADDRESS", "0x0000000000000000000000000000000000000005"),
  TIMELOCK: envAddress("VITE_TIMELOCK_ADDRESS", "0x0000000000000000000000000000000000000006"),
  GAME_ITEMS: envAddress("VITE_GAME_ITEMS_ADDRESS", "0x0000000000000000000000000000000000000007"),
  LOOT: envAddress("VITE_LOOT_ADDRESS", "0x0000000000000000000000000000000000000008"),
  CRAFTING: envAddress("VITE_CRAFTING_ADDRESS", "0x0000000000000000000000000000000000000009"),
  RENTAL_VAULT: envAddress(
    "VITE_RENTAL_VAULT_ADDRESS",
    "0x0000000000000000000000000000000000000010"
  ),
};

export function isConfiguredAddress(address) {
  return !!address && address !== ZERO_ADDRESS;
}

export const ITEM_METADATA = {
  1: { name: "Wood", emoji: "W", type: "resource" },
  2: { name: "Stone", emoji: "S", type: "resource" },
  3: { name: "Iron", emoji: "I", type: "resource" },
  4: { name: "Sword", emoji: "SW", type: "weapon" },
  5: { name: "Shield", emoji: "SH", type: "armor" },
  6: { name: "Rare Chest", emoji: "RC", type: "loot" },
  7: { name: "Legendary Item", emoji: "LG", type: "loot" },
};

export const ITEM_IDS = Object.keys(ITEM_METADATA).map(Number);
export const DEFAULT_RECIPE_IDS = [1, 2, 3, 4, 5];

export const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
];

export const GOVERNANCE_TOKEN_ABI = [
  ...ERC20_ABI,
  "function getVotes(address) view returns (uint256)",
  "function delegates(address) view returns (address)",
  "function delegate(address delegatee)",
];

export const AMM_ABI = [
  "function token0() view returns (address)",
  "function token1() view returns (address)",
  "function lpToken() view returns (address)",
  "function getReserves() view returns (uint112 reserve0, uint112 reserve1)",
  "function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) view returns (uint256)",
  "function addLiquidity(uint256 amount0, uint256 amount1, address to) returns (uint256 liquidity)",
  "function removeLiquidity(uint256 liquidity, address to) returns (uint256 amount0, uint256 amount1)",
  "function swapExactToken0ForToken1(uint256 amountIn, uint256 minAmountOut, address to) returns (uint256 amountOut)",
  "function swapExactToken1ForToken0(uint256 amountIn, uint256 minAmountOut, address to) returns (uint256 amountOut)",
  "event Swap(address indexed sender, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, address to)",
];

export const LP_TOKEN_ABI = [...ERC20_ABI, "function totalSupply() view returns (uint256)"];

export const VAULT_ABI = [
  "function asset() view returns (address)",
  "function totalAssets() view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function convertToAssets(uint256 shares) view returns (uint256)",
  "function previewDeposit(uint256 assets) view returns (uint256)",
  "function previewWithdraw(uint256 assets) view returns (uint256)",
  "function previewRedeem(uint256 shares) view returns (uint256)",
  "function maxDeposit(address) view returns (uint256)",
  "function maxWithdraw(address) view returns (uint256)",
  "function deposit(uint256 assets, address receiver) returns (uint256 shares)",
  "function withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares)",
  "function redeem(uint256 shares, address receiver, address owner) returns (uint256 assets)",
  "function accruedFees() view returns (uint256)",
];

export const GAME_ITEMS_ABI = [
  "function balanceOf(address account, uint256 id) view returns (uint256)",
  "function balanceOfBatch(address[] accounts, uint256[] ids) view returns (uint256[])",
  "function isApprovedForAll(address account, address operator) view returns (bool)",
  "function setApprovalForAll(address operator, bool approved)",
  "function uri(uint256 id) view returns (string)",
];

export const CRAFTING_ABI = [
  "function craft(uint256 recipeId, uint256 amount)",
  "function getRecipe(uint256 recipeId) view returns (uint256[] inputItemIds, uint256[] inputAmounts, uint256 outputItemId, uint256 outputAmount, bool active)",
];

export const LOOT_ABI = [
  "function lootFee() view returns (uint256)",
  "function getDropRates() view returns (uint256[] itemIds, uint16[] dropRatesBps)",
  "function requestLootDrop() returns (uint256 requestId)",
];

export const RENTAL_VAULT_ABI = [
  "function nextListingId() view returns (uint256)",
  "function nextRentalId() view returns (uint256)",
  "function protocolFeeBps() view returns (uint256)",
  "function treasury() view returns (address)",
  "function claimableEarnings(address lender) view returns (uint256)",
  "function listings(uint256 listingId) view returns (address lender, uint256 itemId, uint256 amount, uint256 pricePerDay, uint64 maxDuration, uint8 status, uint256 activeRentalId)",
  "function rentals(uint256 rentalId) view returns (uint256 listingId, address renter, uint64 startTime, uint64 endTime, uint256 totalPayment, uint256 protocolFee, uint8 status)",
  "function listItemForRent(uint256 itemId, uint256 amount, uint256 pricePerDay, uint64 maxDuration) returns (uint256 listingId)",
  "function rentItem(uint256 listingId, uint64 duration) returns (uint256 rentalId)",
  "function endRental(uint256 rentalId)",
  "function cancelListing(uint256 listingId)",
  "function claimEarnings()",
];

export const GOVERNOR_ABI = [
  "function votingDelay() view returns (uint256)",
  "function votingPeriod() view returns (uint256)",
  "function proposalThreshold() view returns (uint256)",
  "function quorumNumerator() view returns (uint256)",
  "function state(uint256 proposalId) view returns (uint8)",
  "function proposalDeadline(uint256 proposalId) view returns (uint256)",
  "function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)",
  "function hasVoted(uint256 proposalId, address account) view returns (bool)",
  "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
  "function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)",
];

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

export const PROPOSAL_STATE_COLOR = {
  Pending: "#f59e0b",
  Active: "#3b82f6",
  Canceled: "#6b7280",
  Defeated: "#ef4444",
  Succeeded: "#10b981",
  Queued: "#8b5cf6",
  Expired: "#6b7280",
  Executed: "#10b981",
};
