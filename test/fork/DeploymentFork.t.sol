// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

interface IGovernorMinimal {
    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function proposalThreshold() external view returns (uint256);
}

contract DeploymentForkTest is Test {
    function testFork_DeployedGovernorParameters() public {
        bool runFork = vm.envOr("RUN_FORK_TESTS", false);
        if (!runFork) return;

        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));
        IGovernorMinimal governor = IGovernorMinimal(vm.envAddress("GOVERNOR_ADDRESS"));

        assertEq(governor.votingDelay(), 7_200);
        assertEq(governor.votingPeriod(), 50_400);
        assertGt(governor.proposalThreshold(), 0);
    }
}
