// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PriceOracle} from "../../src/oracle/PriceOracle.sol";
import {MockV3Aggregator} from "../../src/oracle/mocks/MockV3Aggregator.sol";

contract PriceOracleTest is Test {
    address internal admin = makeAddr("admin");
    address internal user = makeAddr("user");

    MockV3Aggregator internal feed;
    PriceOracle internal oracle;

    function setUp() external {
        feed = new MockV3Aggregator(8, 2_500e8);
        oracle = new PriceOracle(admin, feed, 1 days);
    }

    function testFreshPriceWorks() external view {
        (uint256 price, uint256 updatedAt) = oracle.getLatestPrice();
        assertEq(price, 2_500e8);
        assertEq(updatedAt, block.timestamp);
    }

    function testStalePriceReverts() external {
        vm.warp(block.timestamp + 2 days);

        vm.expectRevert(
            abi.encodeWithSelector(PriceOracle.StalePrice.selector, block.timestamp - 2 days, block.timestamp, 1 days)
        );
        oracle.getLatestPrice();
    }

    function testZeroPriceReverts() external {
        feed.updateAnswer(0);

        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.getLatestPrice();
    }

    function testNegativePriceReverts() external {
        feed.updateAnswer(-1);

        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.getLatestPrice();
    }

    function testAdminCanChangeMaxStaleness() external {
        vm.prank(admin);
        oracle.setMaxStaleness(2 days);

        assertEq(oracle.maxStaleness(), 2 days);
    }

    function testNonAdminCannotChangeMaxStaleness() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        vm.prank(user);
        oracle.setMaxStaleness(2 days);
    }

    function testDecimalsConversionWorks() external view {
        (uint256 price18,) = oracle.getLatestPrice18Decimals();
        assertEq(price18, 2_500e18);
    }

    function testDecimalsConversionHandles18DecimalsFeed() external {
        MockV3Aggregator exactFeed = new MockV3Aggregator(18, 3_000e18);
        PriceOracle exactOracle = new PriceOracle(admin, exactFeed, 1 days);

        (uint256 price18,) = exactOracle.getLatestPrice18Decimals();
        assertEq(price18, 3_000e18);
    }

    function testDecimalsConversionHandlesGreaterThan18Decimals() external {
        MockV3Aggregator highPrecisionFeed = new MockV3Aggregator(20, 4_200e20);
        PriceOracle highPrecisionOracle = new PriceOracle(admin, highPrecisionFeed, 1 days);

        (uint256 price18,) = highPrecisionOracle.getLatestPrice18Decimals();
        assertEq(price18, 4_200e18);
    }

    function testAdminCanChangeFeedAddress() external {
        MockV3Aggregator newFeed = new MockV3Aggregator(8, 1_750e8);

        vm.prank(admin);
        oracle.setFeed(newFeed);

        (uint256 price,) = oracle.getLatestPrice();
        assertEq(price, 1_750e8);
    }

    function testUpdatedAtZeroReverts() external {
        feed.updateRoundData(1, 2_500e8, 0, 0, 1);

        vm.expectRevert(PriceOracle.InvalidTimestamp.selector);
        oracle.getLatestPrice();
    }
}
