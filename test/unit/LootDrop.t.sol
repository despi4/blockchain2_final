// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGameItems1155} from "../../src/interfaces/IGameItems1155.sol";
import {GameItems} from "../../src/token/GameItems.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {LootDrop} from "../../src/loot/LootDrop.sol";
import {MockLootVRFCoordinator} from "../../src/loot/mocks/MockLootVRFCoordinator.sol";

contract LootDropTest is Test {
    address internal admin = makeAddr("admin");
    address internal user = makeAddr("user");
    address internal treasury = makeAddr("treasury");
    address internal attacker = makeAddr("attacker");

    GameItems internal items;
    GoldToken internal gold;
    MockLootVRFCoordinator internal coordinator;
    LootDrop internal lootDrop;

    uint256 internal woodId;
    uint256 internal ironId;
    uint256 internal shieldId;
    uint256 internal legendaryId;

    function setUp() external {
        items = new GameItems(admin, "ipfs://game-items/");
        gold = new GoldToken(admin, admin, 10_000_000 ether);
        coordinator = new MockLootVRFCoordinator();
        lootDrop = new LootDrop(admin, IGameItems1155(address(items)), gold, coordinator, treasury);

        woodId = items.WOOD();
        ironId = items.IRON();
        shieldId = items.SHIELD();
        legendaryId = items.LEGENDARY_ITEM();

        uint256[] memory itemIds = new uint256[](4);
        uint16[] memory rates = new uint16[](4);
        itemIds[0] = woodId;
        itemIds[1] = ironId;
        itemIds[2] = shieldId;
        itemIds[3] = legendaryId;
        rates[0] = 6000;
        rates[1] = 2500;
        rates[2] = 1200;
        rates[3] = 300;

        vm.startPrank(admin);
        items.grantRole(items.MINTER_ROLE(), address(lootDrop));
        lootDrop.setDropRates(itemIds, rates);
        gold.mint(user, 1_000 ether);
        vm.stopPrank();

        vm.prank(user);
        gold.approve(address(lootDrop), type(uint256).max);
    }

    function testRequestLootCreatesPendingRequest() external {
        vm.prank(user);
        uint256 requestId = lootDrop.requestLootDrop();

        (address requester, bool fulfilled) = lootDrop.pendingRequests(requestId);
        assertEq(requester, user);
        assertFalse(fulfilled);
    }

    function testFulfillRandomnessMintsCorrectItem() external {
        vm.prank(user);
        uint256 requestId = lootDrop.requestLootDrop();

        coordinator.fulfillRequest(requestId, 9_900);

        assertEq(items.balanceOf(user, legendaryId), 1);
    }

    function testInvalidRequestReverts() external {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1;

        vm.expectRevert(abi.encodeWithSelector(LootDrop.InvalidRequest.selector, 999));
        vm.prank(address(coordinator));
        lootDrop.fulfillRandomWords(999, randomWords);
    }

    function testOnlyCoordinatorCanFulfill() external {
        vm.prank(user);
        uint256 requestId = lootDrop.requestLootDrop();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 42;

        vm.expectRevert(abi.encodeWithSelector(LootDrop.UnauthorizedCoordinator.selector, attacker));
        vm.prank(attacker);
        lootDrop.fulfillRandomWords(requestId, randomWords);
    }

    function testOnlyAdminCanUpdateDropRates() external {
        uint256[] memory itemIds = new uint256[](1);
        uint16[] memory rates = new uint16[](1);
        itemIds[0] = woodId;
        rates[0] = 10_000;

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        vm.prank(user);
        lootDrop.setDropRates(itemIds, rates);
    }

    function testInvalidDropRatesRevert() external {
        uint256[] memory itemIds = new uint256[](2);
        uint16[] memory rates = new uint16[](2);
        itemIds[0] = woodId;
        itemIds[1] = ironId;
        rates[0] = 7_000;
        rates[1] = 2_000;

        vm.expectRevert(LootDrop.InvalidDropRates.selector);
        vm.prank(admin);
        lootDrop.setDropRates(itemIds, rates);
    }

    function testLootFeeTransferredCorrectlyIfUsed() external {
        vm.prank(admin);
        lootDrop.setLootFee(25 ether);

        uint256 treasuryBefore = gold.balanceOf(treasury);
        uint256 userBefore = gold.balanceOf(user);

        vm.prank(user);
        lootDrop.requestLootDrop();

        assertEq(gold.balanceOf(treasury) - treasuryBefore, 25 ether);
        assertEq(userBefore - gold.balanceOf(user), 25 ether);
    }

    function testNoRandomnessBasedOnTimestamp() external {
        vm.warp(1_000_000);

        vm.prank(user);
        uint256 requestId1 = lootDrop.requestLootDrop();
        vm.prank(user);
        uint256 requestId2 = lootDrop.requestLootDrop();

        coordinator.fulfillRequest(requestId1, 100);
        coordinator.fulfillRequest(requestId2, 9_900);

        assertEq(items.balanceOf(user, woodId), 1);
        assertEq(items.balanceOf(user, legendaryId), 1);
    }

    function testFulfillMarksRequestAsFulfilled() external {
        vm.prank(user);
        uint256 requestId = lootDrop.requestLootDrop();

        coordinator.fulfillRequest(requestId, 500);

        (, bool fulfilled) = lootDrop.pendingRequests(requestId);
        assertTrue(fulfilled);
    }
}
