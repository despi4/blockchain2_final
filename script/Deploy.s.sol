// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {GameFiGovernor} from "../src/governance/GameFiGovernor.sol";
import {GameFiTimelock} from "../src/governance/GameFiTimelock.sol";
import {GameGovernanceToken} from "../src/token/GameGovernanceToken.sol";
import {GoldToken} from "../src/token/GoldToken.sol";
import {IronToken} from "../src/token/IronToken.sol";
import {GameItems} from "../src/token/GameItems.sol";
import {ResourceAMM} from "../src/amm/ResourceAMM.sol";
import {GuildTreasuryVaultV1} from "../src/vault/GuildTreasuryVaultV1.sol";
import {LootDrop} from "../src/loot/LootDrop.sol";
import {MockLootVRFCoordinator} from "../src/loot/mocks/MockLootVRFCoordinator.sol";
import {CraftingSystem} from "../src/crafting/CraftingSystem.sol";
import {ItemRentalVault} from "../src/vault/ItemRentalVault.sol";
import {IGameItems1155} from "../src/interfaces/IGameItems1155.sol";

/// @notice Full bootstrap deployment script for the GameFi Economy protocol.
///         This version deploys the core protocol contracts itself instead of
///         requiring pre-existing addresses in environment variables.
///
/// Optional env overrides:
/// - TREASURY_ADDRESS
/// - ITEMS_BASE_URI
/// - GOV_INITIAL_SUPPLY
/// - GOLD_INITIAL_SUPPLY
/// - IRON_INITIAL_SUPPLY
/// - LOOT_FEE
/// - RENTAL_FEE_BPS
/// - RENTAL_TREASURY
/// - VAULT_FEE_RECIPIENT
/// - SEED_AMM_LIQUIDITY
contract Deploy is Script {
    bytes32 internal constant INITIAL_GOVERNANCE_WIRING_SALT = keccak256("INITIAL_GOVERNANCE_WIRING");

    struct DeployConfig {
        address treasury;
        address rentalTreasury;
        address vaultFeeRecipient;
        string itemsBaseURI;
        uint256 govInitialSupply;
        uint256 goldInitialSupply;
        uint256 ironInitialSupply;
        uint256 lootFee;
        uint256 rentalFeeBps;
        uint256 seedAmmLiquidity;
    }

    struct Deployment {
        GameGovernanceToken govToken;
        GoldToken goldToken;
        IronToken ironToken;
        GameItems gameItems;
        ResourceAMM amm;
        GuildTreasuryVaultV1 vaultImplementation;
        GuildTreasuryVaultV1 vault;
        MockLootVRFCoordinator vrfCoordinator;
        LootDrop lootDrop;
        CraftingSystem craftingSystem;
        ItemRentalVault rentalVault;
        GameFiTimelock timelock;
        GameFiGovernor governor;
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        DeployConfig memory cfg = _loadConfig(deployer);

        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Treasury:", cfg.treasury);

        vm.startBroadcast(deployerKey);
        Deployment memory dep = _deployCore(deployer, cfg);
        _wireGovernance(dep, deployer);
        _grantRuntimeRoles(dep);
        _configureLootDrop(dep.lootDrop, dep.gameItems, cfg.lootFee);
        _configureCrafting(dep.craftingSystem, dep.gameItems);
        _seedAmm(dep.amm, dep.goldToken, dep.ironToken, cfg.seedAmmLiquidity, deployer);
        _seedVault(dep.vault, dep.goldToken, cfg.seedAmmLiquidity, deployer);

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:                Arbitrum Sepolia (chainId %d)", block.chainid);
        console.log("GameGovernanceToken:    %s", address(dep.govToken));
        console.log("GoldToken:              %s", address(dep.goldToken));
        console.log("IronToken:              %s", address(dep.ironToken));
        console.log("GameItems:              %s", address(dep.gameItems));
        console.log("ResourceAMM:            %s", address(dep.amm));
        console.log("AMM LP Token:           %s", address(dep.amm.lpToken()));
        console.log("Vault Implementation:   %s", address(dep.vaultImplementation));
        console.log("Vault Proxy:            %s", address(dep.vault));
        console.log("Mock VRF Coordinator:   %s", address(dep.vrfCoordinator));
        console.log("LootDrop:               %s", address(dep.lootDrop));
        console.log("CraftingSystem:         %s", address(dep.craftingSystem));
        console.log("ItemRentalVault:        %s", address(dep.rentalVault));
        console.log("Governor:               %s", address(dep.governor));
        console.log("Timelock:               %s", address(dep.timelock));
        console.log("\nCopy these into .env / frontend / subgraph config as needed.");
    }

    function _loadConfig(address deployer) internal view returns (DeployConfig memory cfg) {
        cfg.treasury = vm.envOr("TREASURY_ADDRESS", deployer);
        cfg.rentalTreasury = vm.envOr("RENTAL_TREASURY", cfg.treasury);
        cfg.vaultFeeRecipient = vm.envOr("VAULT_FEE_RECIPIENT", cfg.treasury);
        cfg.itemsBaseURI = vm.envOr("ITEMS_BASE_URI", string("ipfs://gamefi-items/"));
        cfg.govInitialSupply = vm.envOr("GOV_INITIAL_SUPPLY", uint256(1_000_000 ether));
        cfg.goldInitialSupply = vm.envOr("GOLD_INITIAL_SUPPLY", uint256(10_000_000 ether));
        cfg.ironInitialSupply = vm.envOr("IRON_INITIAL_SUPPLY", uint256(10_000_000 ether));
        cfg.lootFee = vm.envOr("LOOT_FEE", uint256(10 ether));
        cfg.rentalFeeBps = vm.envOr("RENTAL_FEE_BPS", uint256(500));
        cfg.seedAmmLiquidity = vm.envOr("SEED_AMM_LIQUIDITY", uint256(100_000 ether));
    }

    function _deployCore(address deployer, DeployConfig memory cfg) internal returns (Deployment memory dep) {
        dep.govToken = new GameGovernanceToken(deployer, deployer, cfg.govInitialSupply);
        dep.goldToken = new GoldToken(deployer, deployer, cfg.goldInitialSupply);
        dep.ironToken = new IronToken(deployer, deployer, cfg.ironInitialSupply);
        dep.gameItems = new GameItems(deployer, cfg.itemsBaseURI);
        dep.amm = new ResourceAMM(dep.goldToken, dep.ironToken);
        dep.vaultImplementation = new GuildTreasuryVaultV1();
        dep.vault = _deployVaultProxy(dep.vaultImplementation, dep.goldToken, deployer, cfg.vaultFeeRecipient);
        dep.vrfCoordinator = new MockLootVRFCoordinator();

        IGameItems1155 gameItems1155 = IGameItems1155(address(dep.gameItems));
        dep.lootDrop = new LootDrop(deployer, gameItems1155, dep.goldToken, dep.vrfCoordinator, cfg.treasury);
        dep.craftingSystem = new CraftingSystem(deployer, gameItems1155);
        dep.rentalVault =
            new ItemRentalVault(IERC1155(address(dep.gameItems)), dep.goldToken, deployer, cfg.rentalTreasury, cfg.rentalFeeBps);
        dep.timelock = new GameFiTimelock(deployer);
        dep.governor = new GameFiGovernor(dep.govToken, dep.timelock);
    }

    function _deployVaultProxy(
        GuildTreasuryVaultV1 implementation,
        GoldToken goldToken,
        address deployer,
        address vaultFeeRecipient
    ) internal returns (GuildTreasuryVaultV1 vault) {
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(
                GuildTreasuryVaultV1.initialize, (IERC20(address(goldToken)), deployer, vaultFeeRecipient)
            )
        );
        vault = GuildTreasuryVaultV1(address(proxy));
    }

    function _wireGovernance(Deployment memory dep, address deployer) internal {
        bytes32 proposerRole = dep.timelock.PROPOSER_ROLE();

        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);

        targets[0] = address(dep.timelock);
        calldatas[0] = abi.encodeCall(dep.timelock.grantRole, (proposerRole, address(dep.governor)));

        targets[1] = address(dep.timelock);
        calldatas[1] = abi.encodeCall(dep.timelock.revokeRole, (proposerRole, deployer));

        uint256 delay = dep.timelock.getMinDelay();
        dep.timelock.scheduleBatch(targets, values, calldatas, bytes32(0), INITIAL_GOVERNANCE_WIRING_SALT, delay);

        console.log("Governance handoff scheduled via timelock.");
        console.log("Governor proposer activation ETA (seconds):", delay);

        if (block.chainid == 31337) {
            vm.warp(block.timestamp + delay + 1);
            dep.timelock.executeBatch(targets, values, calldatas, bytes32(0), INITIAL_GOVERNANCE_WIRING_SALT);
            console.log("Governance handoff executed automatically on local chain.");
        }
    }

    function _grantRuntimeRoles(Deployment memory dep) internal {
        dep.gameItems.grantRole(dep.gameItems.MINTER_ROLE(), address(dep.lootDrop));
        dep.gameItems.grantRole(dep.gameItems.MINTER_ROLE(), address(dep.craftingSystem));
        dep.gameItems.grantRole(dep.gameItems.BURNER_ROLE(), address(dep.craftingSystem));
    }

    function _configureLootDrop(LootDrop lootDrop, GameItems gameItems, uint256 lootFee) internal {
        uint256[] memory itemIds = new uint256[](4);
        uint16[] memory rates = new uint16[](4);

        itemIds[0] = gameItems.WOOD();
        itemIds[1] = gameItems.IRON();
        itemIds[2] = gameItems.SHIELD();
        itemIds[3] = gameItems.LEGENDARY_ITEM();

        rates[0] = 6000;
        rates[1] = 2500;
        rates[2] = 1200;
        rates[3] = 300;

        lootDrop.setDropRates(itemIds, rates);
        lootDrop.setLootFee(lootFee);
    }

    function _configureCrafting(CraftingSystem craftingSystem, GameItems gameItems) internal {
        uint256[] memory inputIds = new uint256[](2);
        uint256[] memory inputAmounts = new uint256[](2);

        inputIds[0] = gameItems.WOOD();
        inputIds[1] = gameItems.IRON();
        inputAmounts[0] = 3;
        inputAmounts[1] = 2;

        craftingSystem.setRecipe(1, inputIds, inputAmounts, gameItems.SWORD(), 1, true);
    }

    function _seedAmm(
        ResourceAMM amm,
        GoldToken goldToken,
        IronToken ironToken,
        uint256 seedLiquidity,
        address liquidityReceiver
    ) internal {
        if (seedLiquidity == 0) {
            return;
        }

        goldToken.approve(address(amm), seedLiquidity);
        ironToken.approve(address(amm), seedLiquidity);
        amm.addLiquidity(seedLiquidity, seedLiquidity, liquidityReceiver);
    }

    function _seedVault(
        GuildTreasuryVaultV1 vault,
        GoldToken goldToken,
        uint256 seedLiquidity,
        address shareReceiver
    ) internal {
        if (seedLiquidity == 0) {
            return;
        }

        goldToken.approve(address(vault), seedLiquidity);
        vault.deposit(seedLiquidity, shareReceiver);
    }
}
