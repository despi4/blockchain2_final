// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGameItems1155} from "../../src/interfaces/IGameItems1155.sol";
import {GameItems} from "../../src/token/GameItems.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {LootDrop} from "../../src/loot/LootDrop.sol";
import {MockLootVRFCoordinator} from "../../src/loot/mocks/MockLootVRFCoordinator.sol";

contract LootDropAdditionalTest is Test {
    address internal admin = makeAddr("admin");
    address internal user = makeAddr("user");
    address internal treasury = makeAddr("treasury");
    address internal newTreasury = makeAddr("newTreasury");
    address internal outsider = makeAddr("outsider");

    GameItems internal items;
    GoldToken internal gold;
    MockLootVRFCoordinator internal coordinator;
    MockLootVRFCoordinator internal secondCoordinator;
    LootDrop internal lootDrop;

    function setUp() external {
        items = new GameItems(admin, "ipfs://items/");
        gold = new GoldToken(admin, admin, 1_000_000 ether);
        coordinator = new MockLootVRFCoordinator();
        secondCoordinator = new MockLootVRFCoordinator();
        lootDrop = new LootDrop(admin, IGameItems1155(address(items)), gold, coordinator, treasury);

        uint256[] memory itemIds = new uint256[](2);
        uint16[] memory rates = new uint16[](2);
        itemIds[0] = items.WOOD();
        itemIds[1] = items.LEGENDARY_ITEM();
        rates[0] = 9700;
        rates[1] = 300;

        vm.startPrank(admin);
        items.grantRole(items.MINTER_ROLE(), address(lootDrop));
        lootDrop.setDropRates(itemIds, rates);
        gold.mint(user, 1000 ether);
        vm.stopPrank();

        vm.prank(user);
        gold.approve(address(lootDrop), type(uint256).max);
    }

    function testSetTreasuryAndCoordinator() external {
        vm.prank(admin);
        lootDrop.setTreasury(newTreasury);
        assertEq(lootDrop.treasury(), newTreasury);

        vm.prank(admin);
        lootDrop.setCoordinator(secondCoordinator);
        assertEq(address(lootDrop.coordinator()), address(secondCoordinator));
    }

    function testSetTreasuryRejectsZeroAndUnauthorizedOwnerCalls() external {
        vm.expectRevert(LootDrop.InvalidTreasury.selector);
        vm.prank(admin);
        lootDrop.setTreasury(address(0));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        vm.prank(outsider);
        lootDrop.setLootFee(1 ether);
    }

    function testGetDropRatesAndEmptyRandomWordsRevert() external {
        (uint256[] memory itemIds, uint16[] memory rates) = lootDrop.getDropRates();
        assertEq(itemIds.length, 2);
        assertEq(rates.length, 2);
        assertEq(rates[1], 300);

        vm.prank(user);
        uint256 requestId = lootDrop.requestLootDrop();

        uint256[] memory emptyWords = new uint256[](0);
        vm.expectRevert(abi.encodeWithSelector(LootDrop.InvalidRequest.selector, requestId));
        vm.prank(address(coordinator));
        lootDrop.fulfillRandomWords(requestId, emptyWords);
    }

    function testCannotFulfillTwiceAndUpdatedTreasuryReceivesFees() external {
        vm.prank(admin);
        lootDrop.setTreasury(newTreasury);
        vm.prank(admin);
        lootDrop.setLootFee(5 ether);

        uint256 treasuryBefore = gold.balanceOf(newTreasury);

        vm.prank(user);
        uint256 requestId = lootDrop.requestLootDrop();

        assertEq(gold.balanceOf(newTreasury) - treasuryBefore, 5 ether);

        coordinator.fulfillRequest(requestId, 9999);
        assertEq(items.balanceOf(user, items.LEGENDARY_ITEM()), 1);

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1;
        vm.expectRevert(abi.encodeWithSelector(LootDrop.AlreadyFulfilled.selector, requestId));
        vm.prank(address(coordinator));
        lootDrop.fulfillRandomWords(requestId, randomWords);
    }

    function testCorruptedDropRatesCanReachFallbackRevert() external {
        bytes32 ratesLengthSlot = bytes32(uint256(7));
        vm.store(address(lootDrop), ratesLengthSlot, bytes32(uint256(1)));

        uint256 ratesDataSlot = uint256(keccak256(abi.encode(uint256(7))));
        vm.store(address(lootDrop), bytes32(ratesDataSlot), bytes32(uint256(1000)));

        vm.prank(user);
        uint256 requestId = lootDrop.requestLootDrop();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 9_000;

        vm.expectRevert(LootDrop.InvalidDropRates.selector);
        vm.prank(address(coordinator));
        lootDrop.fulfillRandomWords(requestId, randomWords);
    }
}
