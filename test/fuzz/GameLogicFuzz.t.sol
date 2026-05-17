// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameItems} from "../../src/token/GameItems.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {GameGovernanceToken} from "../../src/token/GameGovernanceToken.sol";
import {CraftingSystem} from "../../src/crafting/CraftingSystem.sol";
import {ItemRentalVault} from "../../src/vault/ItemRentalVault.sol";
import {GameMath} from "../../src/math/GameMath.sol";
import {GameMathYul} from "../../src/math/GameMathYul.sol";
import "../../src/crafting/CraftingSystem.sol";

contract GameLogicFuzzTest is Test {
    GameItems internal items;
    GoldToken internal gold;
    GameGovernanceToken internal govToken;
    CraftingSystem internal crafting;
    ItemRentalVault internal rentalVault;
    GameMath internal mathSol;
    GameMathYul internal mathYul;

    address internal user = makeAddr("user");
    address internal renter = makeAddr("renter");
    address internal treasury = makeAddr("treasury");

    function setUp() public {
        items = new GameItems(address(this), "ipfs://base/");
        gold = new GoldToken(address(this), address(this), 2_000_000 ether);
        govToken = new GameGovernanceToken(address(this), user, 100_000 ether);
        crafting = new CraftingSystem(address(this), IGameItems1155(address(items)));
        rentalVault = new ItemRentalVault(items, gold, address(this), treasury, 500);
        mathSol = new GameMath();
        mathYul = new GameMathYul();

        items.grantRole(items.MINTER_ROLE(), address(crafting));
        items.grantRole(items.BURNER_ROLE(), address(crafting));

        uint256[] memory inputIds = new uint256[](2);
        uint256[] memory inputAmounts = new uint256[](2);
        inputIds[0] = items.WOOD();
        inputIds[1] = items.IRON();
        inputAmounts[0] = 2;
        inputAmounts[1] = 1;
        crafting.setRecipe(1, inputIds, inputAmounts, items.SWORD(), 1, true);

        items.mint(user, items.WOOD(), 100_000, "");
        items.mint(user, items.IRON(), 100_000, "");
        items.mint(user, items.SWORD(), 10, "");
        gold.mint(renter, 100_000 ether);

        vm.prank(user);
        items.setApprovalForAll(address(rentalVault), true);
        vm.prank(renter);
        gold.approve(address(rentalVault), type(uint256).max);
    }

    function testFuzz_CraftAmount(uint256 amount) public {
        amount = bound(amount, 1, 10_000);
        uint256 swordBefore = items.balanceOf(user, items.SWORD());

        vm.prank(user);
        crafting.craft(1, amount);

        assertEq(items.balanceOf(user, items.SWORD()), swordBefore + amount);
        assertEq(items.balanceOf(user, items.WOOD()), 100_000 - amount * 2);
        assertEq(items.balanceOf(user, items.IRON()), 100_000 - amount);
    }

    function testFuzz_RentalDuration(uint64 duration) public {
        duration = uint64(bound(duration, 1, 30));

        vm.startPrank(user);
        items.setApprovalForAll(address(rentalVault), true);
        uint256 listingId = rentalVault.listItemForRent(items.SWORD(), 1, 1 ether, 30);
        vm.stopPrank();

        vm.prank(renter);
        uint256 rentalId = rentalVault.rentItem(listingId, duration);

        (, address actualRenter,, uint64 endTime,,,) = rentalVault.rentals(rentalId);
        assertEq(actualRenter, renter);
        assertEq(endTime, uint64(block.timestamp + uint256(duration) * 1 days));
    }

    function testFuzz_VotingPowerAfterDelegation(uint256 amount) public {
        amount = bound(amount, 1, 50_000 ether);
        govToken.mint(user, amount);

        vm.prank(user);
        govToken.delegate(user);

        assertEq(govToken.getVotes(user), govToken.balanceOf(user));
    }

    function testFuzz_YulFeeEqualsSolidity(uint128 amount, uint16 feeBps) public view {
        feeBps = uint16(bound(feeBps, 0, 10_000));
        uint256 solFee = mathSol.calculateFeeSolidity(amount, feeBps);
        uint256 yulFee = mathYul.calculateFeeYul(amount, feeBps);
        assertEq(yulFee, solFee);
    }
}
