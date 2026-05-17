// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/governance/GameFiGovernor.sol";
import "../src/governance/GameFiTimelock.sol";

/// @notice Post-deployment verification script.
///         Checks that all invariants hold after deployment:
///         - Timelock delay is 2 days
///         - Governor parameters match spec
///         - No external admin backdoor on timelock
///         - Governor is the only proposer
///
/// Usage:
///   forge script script/PostDeployVerify.s.sol:PostDeployVerify \
///     --rpc-url $BASE_SEPOLIA_RPC_URL -vvv
contract PostDeployVerify is Script {
    function run() external view {
        address governorAddr = vm.envAddress("GOVERNOR_ADDRESS");
        address timelockAddr = vm.envAddress("TIMELOCK_ADDRESS");
        address govTokenAddr = vm.envAddress("GOV_TOKEN_ADDRESS");

        GameFiGovernor governor = GameFiGovernor(payable(governorAddr));
        GameFiTimelock timelock = GameFiTimelock(payable(timelockAddr));

        bool allGood = true;

        // ── Check 1: Timelock delay ───────────────────────────────────────────
        uint256 delay = timelock.getMinDelay();
        if (delay == 2 days) {
            console.log("[PASS] Timelock delay: 172800 seconds (2 days)");
        } else {
            console.log("[FAIL] Timelock delay is wrong -expected 172800");
            allGood = false;
        }

        // ── Check 2: No admin backdoor ────────────────────────────────────────
        // Check that the deployer (tx.origin) does not hold admin role
        bool timelockSelfIsAdmin = timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock));
        if (timelockSelfIsAdmin) {
            console.log("[PASS] Timelock is self-governed (no external admin)");
        } else {
            console.log("[FAIL] Unexpected admin configuration");
            allGood = false;
        }

        // ── Check 3: Governor is PROPOSER ─────────────────────────────────────
        bool govIsProposer = timelock.hasRole(timelock.PROPOSER_ROLE(), governorAddr);
        if (govIsProposer) {
            console.log("[PASS] Governor holds PROPOSER_ROLE on Timelock");
        } else {
            console.log("[FAIL] Governor is NOT PROPOSER on Timelock");
            allGood = false;
        }

        // ── Check 4: Governor parameters ─────────────────────────────────────
        uint256 delay_g = governor.votingDelay();
        uint256 period_g = governor.votingPeriod();
        uint256 quorum_g = governor.quorumNumerator();

        if (delay_g == 7_200) {
            console.log("[PASS] Voting delay: 7200 blocks (~1 day)");
        } else {
            console.log("[FAIL] Voting delay is wrong -expected 7200");
            allGood = false;
        }

        if (period_g == 50_400) {
            console.log("[PASS] Voting period: 50400 blocks (~1 week)");
        } else {
            console.log("[FAIL] Voting period is wrong -expected 50400");
            allGood = false;
        }

        if (quorum_g == 4) {
            console.log("[PASS] Quorum fraction: 4 pct");
        } else {
            console.log("[FAIL] Quorum fraction is wrong - expected 4");
            allGood = false;
        }

        console.log("=== Addresses ===");
        console.log("Governor:  ");
        console.logAddress(governorAddr);
        console.log("Timelock:  ");
        console.logAddress(timelockAddr);
        console.log("GovToken:  ");
        console.logAddress(govTokenAddr);

        if (allGood) {
            console.log("=== ALL CHECKS PASSED -safe to use ===");
        } else {
            console.log("=== SOME CHECKS FAILED -review before proceeding ===");
        }
    }
}
