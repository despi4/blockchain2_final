// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {GameConfigV1} from "../src/upgrade/GameConfigV1.sol";
import {GameConfigV2} from "../src/upgrade/GameConfigV2.sol";

contract GameConfigUpgradeTest is Test {
    address internal owner = makeAddr("owner");
    address internal treasury = makeAddr("treasury");
    address internal otherTreasury = makeAddr("otherTreasury");
    address internal attacker = makeAddr("attacker");

    GameConfigV1 internal configV1;
    GameConfigV2 internal configV2;

    function setUp() external {
        GameConfigV1 implementationV1 = new GameConfigV1();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementationV1),
            abi.encodeCall(GameConfigV1.initialize, (owner, treasury, 10 ether, 300, 500, 25 ether, 1 days, true, true))
        );

        configV1 = GameConfigV1(address(proxy));
    }

    function testInitializeWorks() external view {
        assertEq(configV1.owner(), owner);
        assertEq(configV1.treasury(), treasury);
        assertEq(configV1.craftingFee(), 10 ether);
        assertEq(configV1.marketplaceFeeBps(), 300);
        assertEq(configV1.rentalFeeBps(), 500);
        assertEq(configV1.lootFee(), 25 ether);
        assertEq(configV1.maxStaleness(), 1 days);
        assertTrue(configV1.craftingEnabled());
        assertTrue(configV1.lootEnabled());
    }

    function testCannotInitializeTwice() external {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        configV1.initialize(owner, treasury, 1, 1, 1, 1, 1, true, true);
    }

    function testUpdateConfigParameterWorks() external {
        vm.startPrank(owner);
        configV1.setCraftingFee(20 ether);
        configV1.setMarketplaceFeeBps(450);
        configV1.setRentalFeeBps(650);
        configV1.setLootFee(40 ether);
        configV1.setTreasury(otherTreasury);
        configV1.setMaxStaleness(2 days);
        configV1.setCraftingEnabled(false);
        configV1.setLootEnabled(false);
        vm.stopPrank();

        assertEq(configV1.craftingFee(), 20 ether);
        assertEq(configV1.marketplaceFeeBps(), 450);
        assertEq(configV1.rentalFeeBps(), 650);
        assertEq(configV1.lootFee(), 40 ether);
        assertEq(configV1.treasury(), otherTreasury);
        assertEq(configV1.maxStaleness(), 2 days);
        assertFalse(configV1.craftingEnabled());
        assertFalse(configV1.lootEnabled());
    }

    function testUnauthorizedUserCannotUpdateConfig() external {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, attacker));
        vm.prank(attacker);
        configV1.setLootFee(99 ether);
    }

    function testUpgradeToV2Works() external {
        GameConfigV2 implementationV2 = new GameConfigV2();

        vm.prank(owner);
        configV1.upgradeToAndCall(address(implementationV2), "");

        configV2 = GameConfigV2(address(configV1));
        vm.prank(owner);
        configV2.setMaxCraftPerDay(42);

        assertEq(configV2.maxCraftPerDay(), 42);
    }

    function testOldValuesArePreservedAfterUpgrade() external {
        GameConfigV2 implementationV2 = new GameConfigV2();

        vm.prank(owner);
        configV1.setCraftingFee(77 ether);
        vm.prank(owner);
        configV1.setMarketplaceFeeBps(777);
        vm.prank(owner);
        configV1.upgradeToAndCall(address(implementationV2), "");

        configV2 = GameConfigV2(address(configV1));
        assertEq(configV2.craftingFee(), 77 ether);
        assertEq(configV2.marketplaceFeeBps(), 777);
        assertEq(configV2.rentalFeeBps(), 500);
        assertEq(configV2.lootFee(), 25 ether);
        assertEq(configV2.treasury(), treasury);
        assertEq(configV2.maxStaleness(), 1 days);
        assertTrue(configV2.craftingEnabled());
        assertTrue(configV2.lootEnabled());
    }

    function testNewV2FunctionWorks() external {
        GameConfigV2 implementationV2 = new GameConfigV2();

        vm.prank(owner);
        configV1.upgradeToAndCall(address(implementationV2), "");

        configV2 = GameConfigV2(address(configV1));
        vm.prank(owner);
        configV2.setMaxCraftPerDay(100);

        assertEq(configV2.maxCraftPerDay(), 100);
    }

    function testUnauthorizedUpgradeReverts() external {
        GameConfigV2 implementationV2 = new GameConfigV2();

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, attacker));
        vm.prank(attacker);
        configV1.upgradeToAndCall(address(implementationV2), "");
    }
}
