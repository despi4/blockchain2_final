import fs from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const manifestPath = path.join(repoRoot, "deployments", "arbitrum-sepolia.json");
const manifestExamplePath = path.join(repoRoot, "deployments", "arbitrum-sepolia.example.json");
const frontendEnvPath = path.join(repoRoot, "frontend", ".env.local");
const subgraphTemplatePath = path.join(repoRoot, "subgraph", "subgraph.template.yaml");
const subgraphOutputPath = path.join(repoRoot, "subgraph", "subgraph.yaml");

if (!fs.existsSync(manifestPath)) {
  throw new Error(
    `Missing ${manifestPath}. Copy ${manifestExamplePath} to arbitrum-sepolia.json and fill in deployed addresses first.`
  );
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const { addresses = {}, startBlocks = {}, frontend = {} } = manifest;

const requiredKeys = [
  "resourceAmm",
  "gameFiGovernor",
  "gameGovernanceToken",
  "goldToken",
  "gameItems",
  "lootDrop",
  "craftingSystem",
  "guildTreasuryVault",
  "itemRentalVault",
  "timelock",
];

for (const key of requiredKeys) {
  if (!addresses[key]) {
    throw new Error(`Manifest is missing addresses.${key}`);
  }
}

const frontendEnv = [
  `VITE_WALLETCONNECT_PROJECT_ID=${process.env.VITE_WALLETCONNECT_PROJECT_ID || ""}`,
  `VITE_SUBGRAPH_URL=${frontend.subgraphUrl || ""}`,
  `VITE_GOVERNANCE_TOKEN_ADDRESS=${addresses.gameGovernanceToken}`,
  `VITE_GOLD_TOKEN_ADDRESS=${addresses.goldToken}`,
  `VITE_AMM_ADDRESS=${addresses.resourceAmm}`,
  `VITE_VAULT_ADDRESS=${addresses.guildTreasuryVault}`,
  `VITE_GOVERNOR_ADDRESS=${addresses.gameFiGovernor}`,
  `VITE_TIMELOCK_ADDRESS=${addresses.timelock}`,
  `VITE_GAME_ITEMS_ADDRESS=${addresses.gameItems}`,
  `VITE_LOOT_ADDRESS=${addresses.lootDrop}`,
  `VITE_CRAFTING_ADDRESS=${addresses.craftingSystem}`,
  `VITE_RENTAL_VAULT_ADDRESS=${addresses.itemRentalVault}`,
  "",
].join("\n");

fs.writeFileSync(frontendEnvPath, frontendEnv, "utf8");

const template = fs.readFileSync(subgraphTemplatePath, "utf8");
const replacements = {
  "{{RESOURCE_AMM_ADDRESS}}": addresses.resourceAmm,
  "{{RESOURCE_AMM_START_BLOCK}}": String(startBlocks.resourceAmm ?? 0),
  "{{GAMEFI_GOVERNOR_ADDRESS}}": addresses.gameFiGovernor,
  "{{GAMEFI_GOVERNOR_START_BLOCK}}": String(startBlocks.gameFiGovernor ?? 0),
  "{{GAME_GOVERNANCE_TOKEN_ADDRESS}}": addresses.gameGovernanceToken,
  "{{GAME_GOVERNANCE_TOKEN_START_BLOCK}}": String(startBlocks.gameGovernanceToken ?? 0),
  "{{LOOT_DROP_ADDRESS}}": addresses.lootDrop,
  "{{LOOT_DROP_START_BLOCK}}": String(startBlocks.lootDrop ?? 0),
  "{{CRAFTING_SYSTEM_ADDRESS}}": addresses.craftingSystem,
  "{{CRAFTING_SYSTEM_START_BLOCK}}": String(startBlocks.craftingSystem ?? 0),
  "{{GUILD_TREASURY_VAULT_ADDRESS}}": addresses.guildTreasuryVault,
  "{{GUILD_TREASURY_VAULT_START_BLOCK}}": String(startBlocks.guildTreasuryVault ?? 0),
  "{{ITEM_RENTAL_VAULT_ADDRESS}}": addresses.itemRentalVault,
  "{{ITEM_RENTAL_VAULT_START_BLOCK}}": String(startBlocks.itemRentalVault ?? 0),
};

let renderedSubgraph = template;
for (const [placeholder, value] of Object.entries(replacements)) {
  renderedSubgraph = renderedSubgraph.replaceAll(placeholder, value);
}

fs.writeFileSync(subgraphOutputPath, renderedSubgraph, "utf8");

console.log("Wrote frontend/.env.local and subgraph/subgraph.yaml from deployments/arbitrum-sepolia.json");
