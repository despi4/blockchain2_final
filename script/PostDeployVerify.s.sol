// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {GameFiGovernor} from "../src/governance/GameFiGovernor.sol";
import {GameFiTimelock} from "../src/governance/GameFiTimelock.sol";
import {GameItems} from "../src/token/GameItems.sol";

/// @notice Post-deployment sanity checker for GameFi Economy on Arbitrum Sepolia.
///
/// Checks (all addresses read from env vars set by Deploy.s.sol output):
///   [1]  All required addresses are non-zero
///   [2]  Timelock minimum delay == 2 days
///   [3]  Timelock is self-governed (no external admin)
///   [4]  Governor holds PROPOSER_ROLE on Timelock
///   [5]  Deployer does NOT hold PROPOSER_ROLE on Timelock
///   [6]  Voting delay  == 7 200 blocks
///   [7]  Voting period == 50 400 blocks
///   [8]  Quorum numerator == 4 %
///   [9]  Proposal threshold == 10 000 gGAME (1 % of 1 M supply)
///   [10] Timelock is the owner of each Ownable contract
///   [11] Timelock holds DEFAULT_ADMIN_ROLE on each AccessControl contract
///   [12] Deployer does NOT hold DEFAULT_ADMIN_ROLE on any AccessControl contract
///   [13] CraftingSystem holds MINTER + BURNER role on GameItems
///   [14] LootDrop holds MINTER role on GameItems
///
/// Usage (read-only, no broadcast needed):
///   forge script script/PostDeployVerify.s.sol:PostDeployVerify \
///     --rpc-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
contract PostDeployVerify is Script {
    // ── Expected governor parameters ──────────────────────────────────────────
    uint256 private constant EXPECTED_DELAY = 2 days;
    uint256 private constant EXPECTED_VOTING_DELAY = 7_200;
    uint256 private constant EXPECTED_VOTING_PERIOD = 50_400;
    uint256 private constant EXPECTED_QUORUM = 4;
    uint256 private constant EXPECTED_THRESHOLD = 10_000e18;

    uint256 private _passed;
    uint256 private _failed;

    struct Addrs {
        address governor;
        address timelock;
        address govToken;
        address goldToken;
        address gameItems;
        address crafting;
        address loot;
        address vault;
        address rentalVault;
        address oracle;
        address gameConfig;
        address deployer;
    }

    function run() external {
        Addrs memory a;
        a.governor = vm.envAddress("GOVERNOR_ADDRESS");
        a.timelock = vm.envAddress("TIMELOCK_ADDRESS");
        a.govToken = vm.envAddress("GOV_TOKEN_ADDRESS");
        a.goldToken = vm.envAddress("GOLD_TOKEN_ADDRESS");
        a.gameItems = vm.envAddress("GAME_ITEMS_ADDRESS");
        a.crafting = vm.envAddress("CRAFTING_ADDRESS");
        a.loot = vm.envAddress("LOOT_ADDRESS");
        a.vault = vm.envAddress("VAULT_ADDRESS");
        a.rentalVault = vm.envAddress("RENTAL_VAULT_ADDRESS");
        a.oracle = vm.envAddress("PRICE_ORACLE_ADDRESS");
        a.gameConfig = vm.envAddress("GAME_CONFIG_PROXY_ADDRESS");
        a.deployer = vm.envOr("DEPLOYER_ADDRESS", address(0));

        console2.log("=== PostDeployVerify - GameFi Economy ===");
        console2.log("Governor :", a.governor);
        console2.log("Timelock :", a.timelock);

        _checkAddresses(a);
        _checkTimelockAndGovernor(a);
        _checkOwnership(a);
        _checkAccessControl(a);
        _checkItemRoles(a);

        // ── Summary ───────────────────────────────────────────────────────────
        console2.log("\n=== RESULTS ===");
        console2.log("PASSED:", _passed);
        console2.log("FAILED:", _failed);
        if (_failed == 0) {
            console2.log("ALL CHECKS PASSED - safe to proceed.");
        } else {
            console2.log("SOME CHECKS FAILED - review output above before proceeding.");
            revert("PostDeployVerify: verification failed");
        }
    }

    // ── Check groups ──────────────────────────────────────────────────────────

    function _checkAddresses(Addrs memory a) internal {
        // [1] Non-zero addresses
        _check(a.governor != address(0), "[1] Governor address is set");
        _check(a.timelock != address(0), "[1] Timelock address is set");
        _check(a.govToken != address(0), "[1] GovToken address is set");
        _check(a.goldToken != address(0), "[1] GoldToken address is set");
        _check(a.gameItems != address(0), "[1] GameItems address is set");
        _check(a.crafting != address(0), "[1] CraftingSystem address is set");
        _check(a.loot != address(0), "[1] LootDrop address is set");
        _check(a.vault != address(0), "[1] Vault address is set");
        _check(a.rentalVault != address(0), "[1] RentalVault address is set");
        _check(a.oracle != address(0), "[1] PriceOracle address is set");
        _check(a.gameConfig != address(0), "[1] GameConfig address is set");
    }

    function _checkTimelockAndGovernor(Addrs memory a) internal {
        GameFiGovernor governor = GameFiGovernor(payable(a.governor));
        GameFiTimelock timelock = GameFiTimelock(payable(a.timelock));

        // [2] Timelock delay
        _check(timelock.getMinDelay() == EXPECTED_DELAY, "[2] Timelock delay == 2 days");

        // [3] Timelock self-governance (no external admin)
        _check(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), a.timelock), "[3] Timelock is its own DEFAULT_ADMIN");

        // [4] Governor is PROPOSER on Timelock
        _check(timelock.hasRole(timelock.PROPOSER_ROLE(), a.governor), "[4] Governor holds PROPOSER_ROLE on Timelock");

        // [5] Deployer is NOT PROPOSER on Timelock
        if (a.deployer != address(0)) {
            _check(!timelock.hasRole(timelock.PROPOSER_ROLE(), a.deployer), "[5] Deployer does NOT hold PROPOSER_ROLE");
        } else {
            console2.log("[5] SKIP - DEPLOYER_ADDRESS not set, skipping proposer backdoor check");
        }

        // [6-9] Governor parameters
        _check(governor.votingDelay() == EXPECTED_VOTING_DELAY, "[6] votingDelay == 7200 blocks");
        _check(governor.votingPeriod() == EXPECTED_VOTING_PERIOD, "[7] votingPeriod == 50400 blocks");
        _check(governor.quorumNumerator() == EXPECTED_QUORUM, "[8] quorumNumerator == 4%");
        _check(governor.proposalThreshold() == EXPECTED_THRESHOLD, "[9] proposalThreshold == 10000 gGAME");
    }

    function _checkOwnership(Addrs memory a) internal {
        // [10] Timelock owns all Ownable contracts
        _checkOwner(a.vault, a.timelock, "[10] GuildTreasuryVault owner == Timelock");
        _checkOwner(a.rentalVault, a.timelock, "[10] ItemRentalVault owner == Timelock");
        _checkOwner(a.oracle, a.timelock, "[10] PriceOracle owner == Timelock");
        _checkOwner(a.loot, a.timelock, "[10] LootDrop owner == Timelock");
        _checkOwner(a.gameConfig, a.timelock, "[10] GameConfig owner == Timelock");
    }

    function _checkAccessControl(Addrs memory a) internal {
        bytes32 ADMIN = bytes32(0);

        // [11] Timelock holds DEFAULT_ADMIN_ROLE on AccessControl contracts
        _checkRole(a.gameItems, ADMIN, a.timelock, "[11] GameItems DEFAULT_ADMIN == Timelock");
        _checkRole(a.crafting, ADMIN, a.timelock, "[11] CraftingSystem DEFAULT_ADMIN == Timelock");
        _checkRole(a.govToken, ADMIN, a.timelock, "[11] GovToken DEFAULT_ADMIN == Timelock");
        _checkRole(a.goldToken, ADMIN, a.timelock, "[11] GoldToken DEFAULT_ADMIN == Timelock");

        // [12] Deployer does NOT hold DEFAULT_ADMIN_ROLE
        if (a.deployer != address(0)) {
            _checkNoRole(a.gameItems, ADMIN, a.deployer, "[12] Deployer lost GameItems DEFAULT_ADMIN");
            _checkNoRole(a.crafting, ADMIN, a.deployer, "[12] Deployer lost CraftingSystem DEFAULT_ADMIN");
            _checkNoRole(a.govToken, ADMIN, a.deployer, "[12] Deployer lost GovToken DEFAULT_ADMIN");
            _checkNoRole(a.goldToken, ADMIN, a.deployer, "[12] Deployer lost GoldToken DEFAULT_ADMIN");
        } else {
            console2.log("[12] SKIP - DEPLOYER_ADDRESS not set");
        }
    }

    function _checkItemRoles(Addrs memory a) internal {
        GameItems items = GameItems(a.gameItems);

        // [13] CraftingSystem roles on GameItems
        _checkRole(a.gameItems, items.MINTER_ROLE(), a.crafting, "[13] CraftingSystem has MINTER_ROLE");
        _checkRole(a.gameItems, items.BURNER_ROLE(), a.crafting, "[13] CraftingSystem has BURNER_ROLE");

        // [14] LootDrop roles on GameItems
        _checkRole(a.gameItems, items.MINTER_ROLE(), a.loot, "[14] LootDrop has MINTER_ROLE");
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _check(bool condition, string memory label) internal {
        if (condition) {
            console2.log("[PASS]", label);
            _passed++;
        } else {
            console2.log("[FAIL]", label);
            _failed++;
        }
    }

    function _checkOwner(address contractAddr, address expectedOwner, string memory label) internal {
        try Ownable(contractAddr).owner() returns (address actual) {
            _check(actual == expectedOwner, label);
        } catch {
            console2.log("[FAIL]", label, "(owner() call reverted)");
            _failed++;
        }
    }

    function _checkRole(address contractAddr, bytes32 role, address account, string memory label) internal {
        try IAccessControl(contractAddr).hasRole(role, account) returns (bool has) {
            _check(has, label);
        } catch {
            console2.log("[FAIL]", label, "(hasRole() call reverted)");
            _failed++;
        }
    }

    function _checkNoRole(address contractAddr, bytes32 role, address account, string memory label) internal {
        try IAccessControl(contractAddr).hasRole(role, account) returns (bool has) {
            _check(!has, label);
        } catch {
            console2.log("[FAIL]", label, "(hasRole() call reverted)");
            _failed++;
        }
    }
}
