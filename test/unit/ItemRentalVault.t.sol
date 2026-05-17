// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameItems} from "../../src/token/GameItems.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {ItemRentalVault} from "../../src/vault/ItemRentalVault.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract ReentrantLender is IERC1155Receiver {
    ItemRentalVault public immutable vault;
    GameItems public immutable items;
    uint256 public targetRentalId;
    bool public attemptedReentry;

    constructor(ItemRentalVault vault_, GameItems items_) {
        vault = vault_;
        items = items_;
    }

    function approveVault() external {
        items.setApprovalForAll(address(vault), true);
    }

    function listItem(uint256 itemId, uint256 amount, uint256 pricePerDay, uint64 maxDuration)
        external
        returns (uint256 listingId)
    {
        listingId = vault.listItemForRent(itemId, amount, pricePerDay, maxDuration);
    }

    function setTargetRental(uint256 rentalId) external {
        targetRentalId = rentalId;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        if (!attemptedReentry && targetRentalId != 0) {
            attemptedReentry = true;
            try vault.endRental(targetRentalId) {} catch {}
        }
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}

contract ItemRentalVaultTest is Test {
    address internal admin = makeAddr("admin");
    address internal lender = makeAddr("lender");
    address internal renter = makeAddr("renter");
    address internal treasury = makeAddr("treasury");

    GameItems internal items;
    GoldToken internal gold;
    ItemRentalVault internal vault;

    uint256 internal woodId;
    uint256 internal swordId;

    function setUp() external {
        items = new GameItems(admin, "ipfs://game-items/");
        gold = new GoldToken(admin, admin, 10_000_000 ether);
        vault = new ItemRentalVault(items, gold, admin, treasury, 500);

        woodId = items.WOOD();
        swordId = items.SWORD();

        vm.startPrank(admin);
        items.mint(lender, woodId, 100, "");
        items.mint(lender, swordId, 5, "");
        gold.mint(renter, 100_000 ether);
        vm.stopPrank();

        vm.prank(lender);
        items.setApprovalForAll(address(vault), true);
        vm.prank(renter);
        gold.approve(address(vault), type(uint256).max);
    }

    function _listDefault() internal returns (uint256 listingId) {
        vm.prank(lender);
        listingId = vault.listItemForRent(swordId, 2, 100 ether, 7);
    }

    function _rentDefault(uint256 listingId, uint64 duration) internal returns (uint256 rentalId) {
        vm.prank(renter);
        rentalId = vault.rentItem(listingId, duration);
    }

    function testListItem() external {
        uint256 listingId = _listDefault();

        (
            address storedLender,
            uint256 itemId,
            uint256 amount,
            uint256 pricePerDay,
            uint64 maxDuration,
            ItemRentalVault.ListingStatus status,
            uint256 activeRentalId
        ) = vault.listings(listingId);

        assertEq(storedLender, lender);
        assertEq(itemId, swordId);
        assertEq(amount, 2);
        assertEq(pricePerDay, 100 ether);
        assertEq(maxDuration, 7);
        assertEq(uint8(status), uint8(ItemRentalVault.ListingStatus.LISTED));
        assertEq(activeRentalId, 0);
        assertEq(items.balanceOf(address(vault), swordId), 2);
    }

    function testRentItem() external {
        uint256 listingId = _listDefault();
        uint256 rentalId = _rentDefault(listingId, 3);

        (
            uint256 storedListingId,
            address storedRenter,,
            uint64 endTime,
            uint256 totalPayment,
            uint256 protocolFee,
            ItemRentalVault.RentalStatus status
        ) = vault.rentals(rentalId);

        assertEq(storedListingId, listingId);
        assertEq(storedRenter, renter);
        assertEq(totalPayment, 300 ether);
        assertEq(protocolFee, 15 ether);
        assertEq(uint8(status), uint8(ItemRentalVault.RentalStatus.ACTIVE));
        assertGt(endTime, block.timestamp);
    }

    function testCannotRentInactiveListing() external {
        uint256 listingId = _listDefault();

        vm.prank(lender);
        vault.cancelListing(listingId);

        vm.expectRevert(abi.encodeWithSelector(ItemRentalVault.InactiveListing.selector, listingId));
        vm.prank(renter);
        vault.rentItem(listingId, 1);
    }

    function testCannotRentWithDurationGreaterThanMaxDuration() external {
        uint256 listingId = _listDefault();

        vm.expectRevert(ItemRentalVault.InvalidDuration.selector);
        vm.prank(renter);
        vault.rentItem(listingId, 8);
    }

    function testCannotRentWithZeroDuration() external {
        uint256 listingId = _listDefault();

        vm.expectRevert(ItemRentalVault.InvalidDuration.selector);
        vm.prank(renter);
        vault.rentItem(listingId, 0);
    }

    function testPaymentIsTransferred() external {
        uint256 listingId = _listDefault();
        uint256 renterBalanceBefore = gold.balanceOf(renter);

        _rentDefault(listingId, 2);

        assertEq(renterBalanceBefore - gold.balanceOf(renter), 200 ether);
    }

    function testLenderEarningsAreRecorded() external {
        uint256 listingId = _listDefault();

        _rentDefault(listingId, 2);

        assertEq(vault.claimableEarnings(lender), 190 ether);
    }

    function testTreasuryFeeIsRecorded() external {
        uint256 listingId = _listDefault();
        uint256 treasuryBalanceBefore = gold.balanceOf(treasury);

        _rentDefault(listingId, 2);

        assertEq(vault.totalProtocolFeesCollected(), 10 ether);
        assertEq(gold.balanceOf(treasury) - treasuryBalanceBefore, 10 ether);
    }

    function testEndRentalWorks() external {
        uint256 listingId = _listDefault();
        uint256 rentalId = _rentDefault(listingId, 1);

        vm.warp(block.timestamp + 1 days + 1);
        vault.endRental(rentalId);

        (, uint256 itemId, uint256 amount,,,,) = vault.listings(listingId);
        assertEq(items.balanceOf(lender, itemId), 5);
        assertEq(items.balanceOf(address(vault), itemId), 0);
        assertEq(amount, 2);
    }

    function testCannotEndTwice() external {
        uint256 listingId = _listDefault();
        uint256 rentalId = _rentDefault(listingId, 1);

        vm.warp(block.timestamp + 1 days + 1);
        vault.endRental(rentalId);

        vm.expectRevert(abi.encodeWithSelector(ItemRentalVault.RentalAlreadyEnded.selector, rentalId));
        vault.endRental(rentalId);
    }

    function testCancelListingWorksIfNotRented() external {
        uint256 listingId = _listDefault();

        vm.prank(lender);
        vault.cancelListing(listingId);

        (,,,,, ItemRentalVault.ListingStatus status,) = vault.listings(listingId);
        assertEq(uint8(status), uint8(ItemRentalVault.ListingStatus.CANCELLED));
        assertEq(items.balanceOf(lender, swordId), 5);
        assertEq(items.balanceOf(address(vault), swordId), 0);
    }

    function testClaimEarningsWorks() external {
        uint256 listingId = _listDefault();
        _rentDefault(listingId, 2);

        uint256 lenderBalanceBefore = gold.balanceOf(lender);
        vm.prank(lender);
        vault.claimEarnings();

        assertEq(gold.balanceOf(lender) - lenderBalanceBefore, 190 ether);
        assertEq(vault.claimableEarnings(lender), 0);
    }

    function testReentrancyProtectionExists() external {
        ReentrantLender reentrantLender = new ReentrantLender(vault, items);

        vm.startPrank(admin);
        items.mint(address(reentrantLender), swordId, 1, "");
        gold.mint(renter, 1_000 ether);
        vm.stopPrank();

        reentrantLender.approveVault();
        uint256 listingId = reentrantLender.listItem(swordId, 1, 100 ether, 1);
        vm.prank(renter);
        uint256 rentalId = vault.rentItem(listingId, 1);
        reentrantLender.setTargetRental(rentalId);

        vm.warp(block.timestamp + 1 days + 1);
        vault.endRental(rentalId);

        assertTrue(reentrantLender.attemptedReentry());
        (,,,,,, ItemRentalVault.RentalStatus status) = vault.rentals(rentalId);
        assertEq(uint8(status), uint8(ItemRentalVault.RentalStatus.ENDED));
    }

    function testStateMachineTransitionsAreCorrect() external {
        uint256 listingId = _listDefault();
        (,,,,, ItemRentalVault.ListingStatus initialStatus,) = vault.listings(listingId);
        assertEq(uint8(initialStatus), uint8(ItemRentalVault.ListingStatus.LISTED));

        uint256 rentalId = _rentDefault(listingId, 1);
        (,,,,, ItemRentalVault.ListingStatus rentedStatus, uint256 activeRentalId) = vault.listings(listingId);
        assertEq(uint8(rentedStatus), uint8(ItemRentalVault.ListingStatus.RENTED));
        assertEq(activeRentalId, rentalId);

        vm.warp(block.timestamp + 1 days + 1);
        vault.endRental(rentalId);

        (,,,,, ItemRentalVault.ListingStatus endedStatus, uint256 clearedRentalId) = vault.listings(listingId);
        assertEq(uint8(endedStatus), uint8(ItemRentalVault.ListingStatus.RETURNED));
        assertEq(clearedRentalId, 0);
    }

    function testOwnerCanUpdateFeeAndTreasury() external {
        vm.prank(admin);
        vault.setProtocolFeeBps(750);
        assertEq(vault.protocolFeeBps(), 750);

        address newTreasury = makeAddr("newTreasury");
        vm.prank(admin);
        vault.setTreasury(newTreasury);
        assertEq(vault.treasury(), newTreasury);
    }
}
