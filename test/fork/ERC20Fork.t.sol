// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

interface IERC20MetadataMinimal {
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

contract ERC20ForkTest is Test {
    function testFork_ReadExternalERC20Metadata() public {
        bool runFork = vm.envOr("RUN_FORK_TESTS", false);
        if (!runFork) return;

        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));
        IERC20MetadataMinimal token = IERC20MetadataMinimal(vm.envAddress("FORK_ERC20_ADDRESS"));

        assertGt(token.decimals(), 0);
        assertGt(bytes(token.symbol()).length, 0);
    }
}
