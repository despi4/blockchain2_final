// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {CraftingSystem} from "../../src/crafting/CraftingSystem.sol";
import {IGameItems1155} from "../../src/interfaces/IGameItems1155.sol";
import {GameItems} from "../../src/token/GameItems.sol";

contract CraftingSystemTest is Test {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 internal constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 internal constant RECIPE_ID = 1;

    address internal admin = makeAddr("admin");
    address internal user = makeAddr("user");
    address internal stranger = makeAddr("stranger");

    GameItems internal gameItems;
    CraftingSystem internal craftingSystem;

    uint256 internal woodId;
    uint256 internal ironId;
    uint256 internal swordId;

    function setUp() external {
        gameItems = new GameItems(admin, "ipfs://game-items/");

        vm.prank(admin);
        craftingSystem = new CraftingSystem(admin, IGameItems1155(address(gameItems)));

        woodId = gameItems.WOOD();
        ironId = gameItems.IRON();
        swordId = gameItems.SWORD();

        vm.startPrank(admin);
        gameItems.grantRole(MINTER_ROLE, address(craftingSystem));
        gameItems.grantRole(BURNER_ROLE, address(craftingSystem));
        gameItems.mint(user, woodId, 100, "");
        gameItems.mint(user, ironId, 50, "");
        vm.stopPrank();
    }

    function _setSwordRecipe(bool active) internal {
        uint256[] memory inputIds = new uint256[](2);
        uint256[] memory inputAmounts = new uint256[](2);
        inputIds[0] = woodId;
        inputIds[1] = ironId;
        inputAmounts[0] = 3;
        inputAmounts[1] = 2;

        vm.prank(admin);
        craftingSystem.setRecipe(RECIPE_ID, inputIds, inputAmounts, swordId, 1, active);
    }

    function testAdminCanCreateRecipe() external {
        _setSwordRecipe(true);

        (
            uint256[] memory inputIds,
            uint256[] memory inputAmounts,
            uint256 outputItemId,
            uint256 outputAmount,
            bool active
        ) = craftingSystem.getRecipe(RECIPE_ID);

        assertEq(inputIds.length, 2);
        assertEq(inputAmounts.length, 2);
        assertEq(outputItemId, swordId);
        assertEq(outputAmount, 1);
        assertTrue(active);
    }

    function testNonAdminCannotCreateRecipe() external {
        uint256[] memory inputIds = new uint256[](1);
        uint256[] memory inputAmounts = new uint256[](1);
        inputIds[0] = woodId;
        inputAmounts[0] = 2;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, MANAGER_ROLE)
        );
        vm.prank(stranger);
        craftingSystem.setRecipe(RECIPE_ID, inputIds, inputAmounts, swordId, 1, true);
    }

    function testUserCanCraftIfHasResources() external {
        _setSwordRecipe(true);

        vm.prank(user);
        craftingSystem.craft(RECIPE_ID, 1);

        assertEq(gameItems.balanceOf(user, swordId), 1);
    }

    function testCraftBurnsInputs() external {
        _setSwordRecipe(true);

        uint256 woodBefore = gameItems.balanceOf(user, woodId);
        uint256 ironBefore = gameItems.balanceOf(user, ironId);

        vm.prank(user);
        craftingSystem.craft(RECIPE_ID, 1);

        assertEq(gameItems.balanceOf(user, woodId), woodBefore - 3);
        assertEq(gameItems.balanceOf(user, ironId), ironBefore - 2);
    }

    function testCraftMintsOutput() external {
        _setSwordRecipe(true);

        vm.prank(user);
        craftingSystem.craft(RECIPE_ID, 1);

        assertEq(gameItems.balanceOf(user, swordId), 1);
    }

    function testInsufficientInputReverts() external {
        _setSwordRecipe(true);

        vm.prank(admin);
        gameItems.burn(user, ironId, 49);

        vm.expectRevert();
        vm.prank(user);
        craftingSystem.craft(RECIPE_ID, 1);
    }

    function testInactiveRecipeReverts() external {
        _setSwordRecipe(false);

        vm.expectRevert(abi.encodeWithSelector(CraftingSystem.RecipeInactive.selector, RECIPE_ID));
        vm.prank(user);
        craftingSystem.craft(RECIPE_ID, 1);
    }

    function testZeroAmountReverts() external {
        _setSwordRecipe(true);

        vm.expectRevert(CraftingSystem.ZeroCraftAmount.selector);
        vm.prank(user);
        craftingSystem.craft(RECIPE_ID, 0);
    }

    function testPauseBlocksCrafting() external {
        _setSwordRecipe(true);

        vm.prank(admin);
        craftingSystem.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(user);
        craftingSystem.craft(RECIPE_ID, 1);
    }

    function testUnpauseRestoresCrafting() external {
        _setSwordRecipe(true);

        vm.prank(admin);
        craftingSystem.pause();

        vm.prank(admin);
        craftingSystem.unpause();

        vm.prank(user);
        craftingSystem.craft(RECIPE_ID, 1);

        assertEq(gameItems.balanceOf(user, swordId), 1);
    }

    function testBatchCraftingWithAmountGreaterThanOneWorks() external {
        _setSwordRecipe(true);

        vm.prank(user);
        craftingSystem.craft(RECIPE_ID, 4);

        assertEq(gameItems.balanceOf(user, swordId), 4);
        assertEq(gameItems.balanceOf(user, woodId), 88);
        assertEq(gameItems.balanceOf(user, ironId), 42);
    }
}
