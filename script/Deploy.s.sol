// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/governance/GameFiGovernor.sol";
import "../src/governance/GameFiTimelock.sol";

/// @notice Deployment script for GameFi Economy governance layer.
///         Person 1's contracts (Token, AMM, Vault, etc.) are expected to be
///         deployed first; their addresses are passed via environment variables.
///
/// Usage:
///   forge script script/Deploy.s.sol:Deploy \
///     --rpc-url $ARBITRUM_SEPOLIA_RPC_URL   \
///     --broadcast                            \
///     --verify                               \
///     --etherscan-api-key $ARBISCAN_API_KEY  \
///     -vvvv
contract Deploy is Script {
    // ── Addresses of contracts deployed by Person 1 ────────────────────────
    // Set these via env or hardcode after Person 1's deployment
    address govToken = vm.envOr("GOV_TOKEN_ADDRESS", address(0));
    address ammAddr = vm.envOr("AMM_ADDRESS", address(0));
    address vaultAddr = vm.envOr("VAULT_ADDRESS", address(0));
    address lootAddr = vm.envOr("LOOT_ADDRESS", address(0));

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerKey);

        // ── 1. Deploy Timelock with deployer as temp proposer ────────────────
        GameFiTimelock timelock = new GameFiTimelock(deployer);
        console.log("Timelock deployed:", address(timelock));

        // ── 2. Deploy Governor pointing at Timelock ──────────────────────────
        require(govToken != address(0), "Set GOV_TOKEN_ADDRESS env var");
        GameFiGovernor governor = new GameFiGovernor(IVotes(govToken), timelock);
        console.log("Governor deployed:", address(governor));

        // ── 3. Wire Timelock: grant PROPOSER to Governor, revoke deployer ─────
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0)); // anyone executes
        timelock.revokeRole(timelock.PROPOSER_ROLE(), deployer);
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        vm.stopBroadcast();

        // ── 4. Print deployment summary ───────────────────────────────────────
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:        Arbitrum Sepolia (chainId %d)", block.chainid);
        console.log("Governor:       %s", address(governor));
        console.log("Timelock:       %s", address(timelock));
        console.log("GovToken (ext): %s", govToken);
        console.log("AMM (ext):      %s", ammAddr);
        console.log("Vault (ext):    %s", vaultAddr);
        console.log("Loot (ext):     %s", lootAddr);
        console.log("\nUpdate frontend/.env.local with VITE_* addresses.");
        console.log("Update subgraph/subgraph.yaml placeholder addresses and start blocks.");
    }
}
