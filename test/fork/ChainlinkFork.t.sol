// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {AggregatorV3Interface} from "../../src/oracle/interfaces/AggregatorV3Interface.sol";

contract ChainlinkForkTest is Test {
    function testFork_ReadChainlinkFeed() public {
        bool runFork = vm.envOr("RUN_FORK_TESTS", false);
        if (!runFork) return;

        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));
        AggregatorV3Interface feed = AggregatorV3Interface(vm.envAddress("CHAINLINK_PRICE_FEED"));

        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        assertGt(answer, 0);
        assertGt(updatedAt, 0);
        assertGt(feed.decimals(), 0);
    }
}
