// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {GameItems} from "../../src/token/GameItems.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {ItemRentalVault} from "../../src/vault/ItemRentalVault.sol";

contract ItemRentalVaultHandler {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address internal immutable admin;
    address internal immutable treasury;
    GameItems internal immutable items;
    GoldToken internal immutable gold;
    ItemRentalVault internal immutable vault;
    address[] internal actors;
    uint256[] internal itemIds;

    constructor(address admin_, address treasury_, GameItems items_, GoldToken gold_, ItemRentalVault vault_) {
        admin = admin_;
        treasury = treasury_;
        items = items_;
        gold = gold_;
        vault = vault_;

        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));

        itemIds.push(items.WOOD());
        itemIds.push(items.SWORD());

        vm.startPrank(admin);
        for (uint256 i = 0; i < actors.length; ++i) {
            items.mint(actors[i], itemIds[0], 50, "");
            items.mint(actors[i], itemIds[1], 10, "");
            gold.mint(actors[i], 100_000 ether);
        }
        vm.stopPrank();

        for (uint256 i = 0; i < actors.length; ++i) {
            vm.prank(actors[i]);
            items.setApprovalForAll(address(vault), true);
            vm.prank(actors[i]);
            gold.approve(address(vault), type(uint256).max);
        }
    }

    function listItem(uint256 actorSeed, uint256 itemSeed, uint256 amount, uint256 pricePerDay, uint64 maxDuration) external {
        address actor = actors[actorSeed % actors.length];
        uint256 itemId = itemIds[itemSeed % itemIds.length];
        uint256 balance = items.balanceOf(actor, itemId);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);
        pricePerDay = bound(pricePerDay, 1 ether, 1_000 ether);
        maxDuration = uint64(bound(maxDuration, 1, 7));

        vm.prank(actor);
        vault.listItemForRent(itemId, amount, pricePerDay, maxDuration);
    }

    function rentItem(uint256 actorSeed, uint256 listingSeed, uint64 duration) external {
        uint256 nextListingId = vault.nextListingId();
        if (nextListingId == 0) return;

        uint256 listingId = bound(listingSeed, 1, nextListingId);
        (address lender,,,,, ItemRentalVault.ListingStatus status,) = vault.listings(listingId);
        if (status != ItemRentalVault.ListingStatus.LISTED) return;

        address actor = actors[actorSeed % actors.length];
        if (actor == lender) {
            actor = actors[(actorSeed + 1) % actors.length];
        }

        (,,,, uint64 maxDuration,,) = vault.listings(listingId);
        duration = uint64(bound(duration, 1, maxDuration));

        vm.prank(actor);
        try vault.rentItem(listingId, duration) {} catch {}
    }

    function endRental(uint256 rentalSeed) external {
        uint256 nextRentalId = vault.nextRentalId();
        if (nextRentalId == 0) return;

        uint256 rentalId = bound(rentalSeed, 1, nextRentalId);
        (, , , uint64 endTime, , , ItemRentalVault.RentalStatus status) = vault.rentals(rentalId);
        if (status != ItemRentalVault.RentalStatus.ACTIVE) return;

        vm.warp(endTime + 1);
        vault.endRental(rentalId);
    }

    function cancelListing(uint256 actorSeed, uint256 listingSeed) external {
        uint256 nextListingId = vault.nextListingId();
        if (nextListingId == 0) return;

        uint256 listingId = bound(listingSeed, 1, nextListingId);
        (address lender,,,,, ItemRentalVault.ListingStatus status,) = vault.listings(listingId);
        if (status != ItemRentalVault.ListingStatus.LISTED) return;

        address actor = actors[actorSeed % actors.length];
        if (actor != lender) return;

        vm.prank(actor);
        vault.cancelListing(listingId);
    }

    function claimEarnings(uint256 actorSeed) external {
        address actor = actors[actorSeed % actors.length];
        if (vault.claimableEarnings(actor) == 0) return;

        vm.prank(actor);
        vault.claimEarnings();
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function itemIdAt(uint256 index) external view returns (uint256) {
        return itemIds[index];
    }

    function itemCount() external view returns (uint256) {
        return itemIds.length;
    }

    function bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256 result) {
        if (min == max) return min;
        return min + (x % (max - min + 1));
    }

    function makeAddr(string memory name) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(name)))));
    }
}

contract ItemRentalVaultInvariantTest is StdInvariant, Test {
    address internal admin = makeAddr("admin");
    address internal treasury = makeAddr("treasury");

    GameItems internal items;
    GoldToken internal gold;
    ItemRentalVault internal vault;
    ItemRentalVaultHandler internal handler;

    function setUp() external {
        items = new GameItems(admin, "ipfs://game-items/");
        gold = new GoldToken(admin, admin, 10_000_000 ether);
        vault = new ItemRentalVault(items, gold, admin, treasury, 500);
        handler = new ItemRentalVaultHandler(admin, treasury, items, gold, vault);
        targetContract(address(handler));
    }

    function invariant_listedOrRentedItemsRemainCustodiedAndNotWithdrawn() external view {
        uint256 nextListingId = vault.nextListingId();
        uint256 itemCount = handler.itemCount();

        for (uint256 itemIndex = 0; itemIndex < itemCount; ++itemIndex) {
            uint256 itemId = handler.itemIdAt(itemIndex);
            uint256 reservedAmount;

            for (uint256 listingId = 1; listingId <= nextListingId; ++listingId) {
                (, uint256 listedItemId, uint256 amount,,, ItemRentalVault.ListingStatus status,) = vault.listings(listingId);
                if (
                    listedItemId == itemId &&
                    (status == ItemRentalVault.ListingStatus.LISTED || status == ItemRentalVault.ListingStatus.RENTED)
                ) {
                    reservedAmount += amount;
                }
            }

            assertEq(items.balanceOf(address(vault), itemId), reservedAmount);
        }
    }
}
