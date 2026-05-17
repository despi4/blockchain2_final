// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {GameItems} from "../../src/token/GameItems.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {ItemRentalVault} from "../../src/vault/ItemRentalVault.sol";
import {GameConfigV1} from "../../src/upgrade/GameConfigV1.sol";

contract RentalHandler is Test {
    GameItems public items;
    GoldToken public gold;
    ItemRentalVault public vault;
    address public lender = address(0x1111);
    address public renter = address(0x2222);

    constructor(GameItems items_, GoldToken gold_, ItemRentalVault vault_) {
        items = items_;
        gold = gold_;
        vault = vault_;

        vm.prank(lender);
        items.setApprovalForAll(address(vault), true);
        vm.prank(renter);
        gold.approve(address(vault), type(uint256).max);
    }

    function listAndRent(uint256 pricePerDay, uint64 duration) external {
        pricePerDay = bound(pricePerDay, 1, 10 ether);
        duration = uint64(bound(duration, 1, 7));

        items.mint(lender, items.SWORD(), 1, "");
        gold.mint(renter, pricePerDay * duration);

        vm.prank(lender);
        uint256 listingId = vault.listItemForRent(items.SWORD(), 1, pricePerDay, 7);
        vm.prank(renter);
        try vault.rentItem(listingId, duration) {} catch {}
    }
}

contract GameItemsHandler is Test {
    GameItems public items;
    uint256 public mintedWood;
    uint256 public burnedWood;
    address public user = address(0x3333);

    constructor(GameItems items_) {
        items = items_;
    }

    function mintWood(uint256 amount) external {
        amount = bound(amount, 1, 1_000);
        mintedWood += amount;
        items.mint(user, items.WOOD(), amount, "");
    }

    function burnWood(uint256 amount) external {
        uint256 bal = items.balanceOf(user, items.WOOD());
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        burnedWood += amount;
        items.burn(user, items.WOOD(), amount);
    }
}

contract GameSystemInvariantTest is Test {
    GameItems internal items;
    GoldToken internal gold;
    ItemRentalVault internal rentalVault;
    RentalHandler internal rentalHandler;
    GameItemsHandler internal itemsHandler;
    GameConfigV1 internal config;
    address internal timelock = address(0x9999);
    address internal treasury = address(0x7777);

    function setUp() public {
        items = new GameItems(address(this), "ipfs://base/");
        gold = new GoldToken(address(this), address(this), 0);
        rentalVault = new ItemRentalVault(items, gold, address(this), treasury, 500);

        rentalHandler = new RentalHandler(items, gold, rentalVault);
        itemsHandler = new GameItemsHandler(items);
        items.grantRole(items.MINTER_ROLE(), address(rentalHandler));
        gold.grantRole(gold.MINTER_ROLE(), address(rentalHandler));
        items.grantRole(items.MINTER_ROLE(), address(itemsHandler));
        items.grantRole(items.BURNER_ROLE(), address(itemsHandler));

        GameConfigV1 impl = new GameConfigV1();
        bytes memory data = abi.encodeCall(
            GameConfigV1.initialize,
            (timelock, treasury, 1 ether, 30, 500, 10 ether, 1 days, true, true)
        );
        config = GameConfigV1(address(new ERC1967Proxy(address(impl), data)));

        targetContract(address(rentalHandler));
        targetContract(address(itemsHandler));
    }

    function invariant_RentalProtocolFeesEqualTreasuryBalance() public view {
        assertEq(gold.balanceOf(treasury), rentalVault.totalProtocolFeesCollected());
    }

    function invariant_ERC1155WoodSupplyMatchesMintedMinusBurned() public view {
        assertEq(items.totalSupply(items.WOOD()), itemsHandler.mintedWood() - itemsHandler.burnedWood());
    }

    function invariant_GameConfigOwnerIsTimelock() public view {
        assertEq(config.owner(), timelock);
    }
}
