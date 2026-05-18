// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {GameGovernanceToken} from "../src/token/GameGovernanceToken.sol";
import {GoldToken} from "../src/token/GoldToken.sol";
import {IronToken} from "../src/token/IronToken.sol";
import {WoodToken} from "../src/token/WoodToken.sol";
import {GameItems} from "../src/token/GameItems.sol";
import {CraftingSystem} from "../src/crafting/CraftingSystem.sol";
import {ResourceAMM} from "../src/amm/ResourceAMM.sol";
import {GameFactory} from "../src/factory/GameFactory.sol";
import {GuildTreasuryVaultV1} from "../src/vault/GuildTreasuryVaultV1.sol";
import {ItemRentalVault} from "../src/vault/ItemRentalVault.sol";
import {GameConfigV1} from "../src/upgrade/GameConfigV1.sol";
import {LootDrop} from "../src/loot/LootDrop.sol";
import {MockLootVRFCoordinator} from "../src/loot/mocks/MockLootVRFCoordinator.sol";
import {PriceOracle} from "../src/oracle/PriceOracle.sol";
import {MockV3Aggregator} from "../src/oracle/mocks/MockV3Aggregator.sol";
import {GameMathYul} from "../src/math/GameMathYul.sol";
import {GameFiGovernor} from "../src/governance/GameFiGovernor.sol";
import {GameFiTimelock} from "../src/governance/GameFiTimelock.sol";
import {IGameItems1155} from "../src/interfaces/IGameItems1155.sol";

/// @notice Full GameFi Economy protocol deployment for Arbitrum Sepolia.
///
/// Deployment order:
///   1.  GameGovernanceToken  — ERC20Votes governance token (1 M supply)
///   2.  GoldToken / IronToken / WoodToken — resource ERC20s (10 M each)
///   3.  GameItems            — ERC1155 item registry
///   4.  CraftingSystem       — burns inputs, mints crafted items
///   5.  MockLootVRFCoordinator — deterministic VRF mock (testnet only)
///   6.  LootDrop             — randomness-backed item drops
///   7.  ItemRentalVault      — custodial ERC1155 rental market
///   8.  GuildTreasuryVault   — ERC4626 upgradeable vault (UUPS proxy)
///   9.  GameConfigV1         — DAO-governed protocol config (UUPS proxy)
///   10. ResourceAMM          — GOLD/IRON constant-product pool
///   11. GameFactory          — CREATE + CREATE2 AMM factory
///   12. MockV3Aggregator     — mock Chainlink price feed (testnet only)
///   13. PriceOracle          — staleness-checked price wrapper
///   14. GameMathYul          — Yul benchmark/demo contract
///   15. GameFiTimelock       — 2-day timelock (self-admin, no backdoor)
///   16. GameFiGovernor       — OZ Governor wired to Timelock
///
/// After deployment:
///   - CraftingSystem gets MINTER + BURNER role on GameItems
///   - LootDrop gets MINTER role on GameItems
///   - 3 initial crafting recipes are created
///   - LootDrop drop rates + fee are configured
///   - All Ownable contracts transfer ownership to Timelock
///   - All AccessControl contracts grant DEFAULT_ADMIN_ROLE to Timelock, deployer renounces
///   - Addresses written to deployments/arbitrum-sepolia.json
///
/// Usage:
///   forge script script/Deploy.s.sol:Deploy \
///     --rpc-url $ARBITRUM_SEPOLIA_RPC_URL    \
///     --broadcast --verify                   \
///     --etherscan-api-key $ARBISCAN_API_KEY  \
///     -vvvv
contract Deploy is Script {
    uint256 constant GOV_SUPPLY = 1_000_000e18;
    uint256 constant RESOURCE_SUPPLY = 10_000_000e18;

    // Packed struct avoids "Stack too deep" with >16 local variables
    struct Deployed {
        address govToken;
        address goldToken;
        address ironToken;
        address woodToken;
        address gameItems;
        address crafting;
        address mockVRF;
        address lootDrop;
        address rentalVault;
        address vaultImpl;
        address vault; // proxy
        address configImpl;
        address gameConfig; // proxy
        address amm;
        address factory;
        address mockFeed;
        address oracle;
        address gameMath;
        address timelock;
        address governor;
    }

    function run() external {
        // Use msg.sender (set by --private-key CLI flag) so Foundry reads the
        // real on-chain nonce from the fork instead of starting from 0.
        address deployer = msg.sender;

        console2.log("=== GameFi Economy - Arbitrum Sepolia ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        Deployed memory d;

        vm.startBroadcast();

        // ── 1. Governance token ───────────────────────────────────────────────
        d.govToken = address(new GameGovernanceToken(deployer, deployer, GOV_SUPPLY));

        // ── 2. Resource ERC20 tokens ──────────────────────────────────────────
        d.goldToken = address(new GoldToken(deployer, deployer, RESOURCE_SUPPLY));
        d.ironToken = address(new IronToken(deployer, deployer, RESOURCE_SUPPLY));
        d.woodToken = address(new WoodToken(deployer, deployer, RESOURCE_SUPPLY));

        // ── 3. ERC1155 game items ─────────────────────────────────────────────
        d.gameItems = address(new GameItems(deployer, "https://gamefi.example/items/{id}.json"));

        // ── 4. Crafting system ────────────────────────────────────────────────
        d.crafting = address(new CraftingSystem(deployer, IGameItems1155(d.gameItems)));

        // ── 5. Mock VRF coordinator (testnet randomness source) ───────────────
        d.mockVRF = address(new MockLootVRFCoordinator());

        // ── 6. Loot drop (treasury = deployer; updated to vault below) ─────────
        d.lootDrop = address(
            new LootDrop(
                deployer, IGameItems1155(d.gameItems), IERC20(d.goldToken), MockLootVRFCoordinator(d.mockVRF), deployer
            )
        );

        // ── 7. Item rental vault (2% protocol fee) ────────────────────────────
        d.rentalVault =
            address(new ItemRentalVault(IERC1155(d.gameItems), IERC20(d.goldToken), deployer, deployer, 200));

        // ── 8. Guild treasury vault — UUPS proxy over GuildTreasuryVaultV1 ────
        d.vaultImpl = address(new GuildTreasuryVaultV1());
        d.vault = address(
            new ERC1967Proxy(
                d.vaultImpl, abi.encodeCall(GuildTreasuryVaultV1.initialize, (IERC20(d.goldToken), deployer, deployer))
            )
        );

        // ── 9. Protocol config — UUPS proxy over GameConfigV1 ─────────────────
        d.configImpl = address(new GameConfigV1());
        d.gameConfig = address(
            new ERC1967Proxy(
                d.configImpl,
                abi.encodeCall(
                    GameConfigV1.initialize,
                    (
                        deployer,
                        d.vault, // treasury = the vault
                        0, // craftingFee: free
                        50, // marketplaceFeeBps: 0.5%
                        200, // rentalFeeBps: 2%
                        1e15, // lootFee: 0.001 GOLD
                        3600, // maxStaleness: 1 hour
                        true, // craftingEnabled
                        true // lootEnabled
                    )
                )
            )
        );

        // ── 10. AMM: GOLD/IRON constant-product pool ──────────────────────────
        //         ResourceLPToken is deployed inside ResourceAMM constructor.
        d.amm = address(new ResourceAMM(IERC20(d.goldToken), IERC20(d.ironToken)));

        // ── 11. Factory ───────────────────────────────────────────────────────
        d.factory = address(new GameFactory());

        // ── 12. Mock price feed (testnet: $1.00, 8 decimals) ──────────────────
        d.mockFeed = address(new MockV3Aggregator(8, 1e8));

        // ── 13. Price oracle ──────────────────────────────────────────────────
        d.oracle = address(new PriceOracle(deployer, MockV3Aggregator(d.mockFeed), 3600));

        // ── 14. GameMathYul benchmark/demo ────────────────────────────────────
        d.gameMath = address(new GameMathYul());

        // ── 15 + 16. Timelock + Governor (nonce-prediction breaks circular dep) ─
        //  Governor needs Timelock address; Timelock needs Governor address.
        //  Solution: predict the Governor's CREATE address one slot ahead.
        uint256 timelockNonce = uint256(vm.getNonce(deployer));
        address predictedGovernor = vm.computeCreateAddress(deployer, timelockNonce + 1);
        d.timelock = address(new GameFiTimelock(predictedGovernor));
        d.governor = address(new GameFiGovernor(IVotes(d.govToken), GameFiTimelock(payable(d.timelock))));
        require(d.governor == predictedGovernor, "Deploy: governor address mismatch (nonce drift)");

        // ── 17. Role grants ───────────────────────────────────────────────────
        GameItems items = GameItems(d.gameItems);
        items.grantRole(items.MINTER_ROLE(), d.crafting);
        items.grantRole(items.BURNER_ROLE(), d.crafting);
        items.grantRole(items.MINTER_ROLE(), d.lootDrop);

        // ── 18. Initial crafting recipes ──────────────────────────────────────
        _setupRecipes(CraftingSystem(d.crafting));

        // ── 19. Initial loot drop configuration ──────────────────────────────
        _setupLoot(LootDrop(d.lootDrop), d.vault);

        // ── 20. Update rental vault treasury to the guild vault ───────────────
        ItemRentalVault(d.rentalVault).setTreasury(d.vault);

        // ── 21. Delegate governance votes to deployer (enables proposing) ─────
        GameGovernanceToken(d.govToken).delegate(deployer);

        // ── 22. Surrender all admin rights to Timelock ────────────────────────
        _transferToTimelock(deployer, d);

        vm.stopBroadcast();

        // ── 23. Output and persist ────────────────────────────────────────────
        _printAndSave(deployer, d);
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    function _setupRecipes(CraftingSystem crafting) internal {
        uint256[] memory in2 = new uint256[](2);
        uint256[] memory am2 = new uint256[](2);
        uint256[] memory in1 = new uint256[](1);
        uint256[] memory am1 = new uint256[](1);

        // Recipe 1: 2×Wood + 1×Stone → 1×Sword
        in2[0] = 1;
        in2[1] = 2;
        am2[0] = 2;
        am2[1] = 1;
        crafting.setRecipe(1, in2, am2, 4, 1, true);

        // Recipe 2: 2×Iron + 1×Wood → 1×Shield
        in2[0] = 3;
        in2[1] = 1;
        am2[0] = 2;
        am2[1] = 1;
        crafting.setRecipe(2, in2, am2, 5, 1, true);

        // Recipe 3: 3×Wood → 1×RareChest
        in1[0] = 1;
        am1[0] = 3;
        crafting.setRecipe(3, in1, am1, 6, 1, true);
    }

    function _setupLoot(LootDrop loot, address vaultAddr) internal {
        uint256[] memory ids = new uint256[](5);
        uint16[] memory bps = new uint16[](5);
        ids[0] = 1;
        bps[0] = 4000; // Wood      40%
        ids[1] = 2;
        bps[1] = 3000; // Stone     30%
        ids[2] = 3;
        bps[2] = 2000; // Iron      20%
        ids[3] = 6;
        bps[3] = 900; // RareChest  9%
        ids[4] = 7;
        bps[4] = 100; // Legendary  1%
        loot.setDropRates(ids, bps);
        loot.setLootFee(1e15); // 0.001 GOLD
        loot.setTreasury(vaultAddr);
    }

    function _transferToTimelock(address deployer, Deployed memory d) internal {
        address tl = d.timelock;

        // Ownable contracts → single-step ownership transfer
        PriceOracle(d.oracle).transferOwnership(tl);
        LootDrop(d.lootDrop).transferOwnership(tl);
        ItemRentalVault(d.rentalVault).transferOwnership(tl);
        GuildTreasuryVaultV1(d.vault).transferOwnership(tl);
        GameConfigV1(d.gameConfig).transferOwnership(tl);

        // AccessControl contracts → grant Timelock DEFAULT_ADMIN_ROLE then deployer renounces
        bytes32 ADMIN = bytes32(0); // DEFAULT_ADMIN_ROLE

        GameItems items = GameItems(d.gameItems);
        items.grantRole(ADMIN, tl);
        items.renounceRole(ADMIN, deployer);

        CraftingSystem crafting = CraftingSystem(d.crafting);
        crafting.grantRole(ADMIN, tl);
        crafting.renounceRole(ADMIN, deployer);

        GameGovernanceToken govToken = GameGovernanceToken(d.govToken);
        govToken.grantRole(ADMIN, tl);
        govToken.renounceRole(ADMIN, deployer);

        GoldToken goldToken = GoldToken(d.goldToken);
        goldToken.grantRole(ADMIN, tl);
        goldToken.renounceRole(ADMIN, deployer);

        IronToken ironToken = IronToken(d.ironToken);
        ironToken.grantRole(ADMIN, tl);
        ironToken.renounceRole(ADMIN, deployer);

        WoodToken woodToken = WoodToken(d.woodToken);
        woodToken.grantRole(ADMIN, tl);
        woodToken.renounceRole(ADMIN, deployer);
    }

    function _printAndSave(address deployer, Deployed memory d) internal {
        console2.log("\n=== DEPLOYED ADDRESSES ===");
        console2.log("GameGovernanceToken :", d.govToken);
        console2.log("GoldToken           :", d.goldToken);
        console2.log("IronToken           :", d.ironToken);
        console2.log("WoodToken           :", d.woodToken);
        console2.log("GameItems           :", d.gameItems);
        console2.log("CraftingSystem      :", d.crafting);
        console2.log("ResourceAMM         :", d.amm);
        console2.log("ResourceLPToken     :", address(ResourceAMM(d.amm).lpToken()));
        console2.log("GuildTreasuryVault  :", d.vault);
        console2.log("ItemRentalVault     :", d.rentalVault);
        console2.log("LootDrop            :", d.lootDrop);
        console2.log("PriceOracle         :", d.oracle);
        console2.log("GameConfig          :", d.gameConfig);
        console2.log("GameFactory         :", d.factory);
        console2.log("GameMathYul         :", d.gameMath);
        console2.log("GameFiTimelock      :", d.timelock);
        console2.log("GameFiGovernor      :", d.governor);
        console2.log("--- testnet helpers ---");
        console2.log("MockVRFCoordinator  :", d.mockVRF);
        console2.log("MockPriceFeed       :", d.mockFeed);
        console2.log("VaultImpl           :", d.vaultImpl);
        console2.log("GameConfigImpl      :", d.configImpl);
        console2.log("==========================");
        console2.log("Next: node script/syncDeploymentConfig.mjs");

        // Write JSON file
        string memory j = "d";
        vm.serializeString(j, "network", "arbitrum-sepolia");
        vm.serializeUint(j, "chainId", 421614);
        vm.serializeAddress(j, "deployer", deployer);
        vm.serializeAddress(j, "gameGovernanceToken", d.govToken);
        vm.serializeAddress(j, "goldToken", d.goldToken);
        vm.serializeAddress(j, "ironToken", d.ironToken);
        vm.serializeAddress(j, "woodToken", d.woodToken);
        vm.serializeAddress(j, "gameItems", d.gameItems);
        vm.serializeAddress(j, "craftingSystem", d.crafting);
        vm.serializeAddress(j, "resourceAmm", d.amm);
        vm.serializeAddress(j, "resourceLpToken", address(ResourceAMM(d.amm).lpToken()));
        vm.serializeAddress(j, "guildTreasuryVault", d.vault);
        vm.serializeAddress(j, "guildTreasuryVaultImpl", d.vaultImpl);
        vm.serializeAddress(j, "itemRentalVault", d.rentalVault);
        vm.serializeAddress(j, "lootDrop", d.lootDrop);
        vm.serializeAddress(j, "priceOracle", d.oracle);
        vm.serializeAddress(j, "mockPriceFeed", d.mockFeed);
        vm.serializeAddress(j, "gameConfig", d.gameConfig);
        vm.serializeAddress(j, "gameConfigImpl", d.configImpl);
        vm.serializeAddress(j, "gameFactory", d.factory);
        vm.serializeAddress(j, "gameMathYul", d.gameMath);
        vm.serializeAddress(j, "gameFiTimelock", d.timelock);
        vm.serializeAddress(j, "gameFiGovernor", d.governor);
        string memory out = vm.serializeAddress(j, "mockVRFCoordinator", d.mockVRF);
        vm.writeJson(out, "deployments/arbitrum-sepolia.json");
        console2.log("Wrote deployments/arbitrum-sepolia.json");
    }
}
