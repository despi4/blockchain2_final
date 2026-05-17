// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {CraftingSystem} from "../../src/crafting/CraftingSystem.sol";
import {IGameItems1155} from "../../src/interfaces/IGameItems1155.sol";
import {GameItems} from "../../src/token/GameItems.sol";

contract CraftingSystemAdditionalTest is Test {
    address internal admin = makeAddr("admin");
    address internal user = makeAddr("user");
    address internal outsider = makeAddr("outsider");

    GameItems internal gameItems;
    CraftingSystem internal craftingSystem;

    function setUp() external {
        gameItems = new GameItems(admin, "ipfs://items/");
        craftingSystem = new CraftingSystem(admin, IGameItems1155(address(gameItems)));

        vm.startPrank(admin);
        gameItems.grantRole(gameItems.MINTER_ROLE(), address(craftingSystem));
        gameItems.grantRole(gameItems.BURNER_ROLE(), address(craftingSystem));
        vm.stopPrank();
    }

    function testSetRecipeRejectsBadArraysAndInvalidOutputs() external {
        uint256[] memory inputIds = new uint256[](2);
        uint256[] memory inputAmounts = new uint256[](1);
        uint256 swordId = gameItems.SWORD();
        inputIds[0] = gameItems.WOOD();
        inputIds[1] = gameItems.IRON();
        inputAmounts[0] = 1;

        vm.expectRevert(CraftingSystem.InvalidInputLengths.selector);
        vm.prank(admin);
        craftingSystem.setRecipe(1, inputIds, inputAmounts, swordId, 1, true);

        inputIds = new uint256[](1);
        inputAmounts = new uint256[](1);
        inputIds[0] = gameItems.WOOD();
        inputAmounts[0] = 1;

        vm.expectRevert(CraftingSystem.InvalidRecipe.selector);
        vm.prank(admin);
        craftingSystem.setRecipe(1, inputIds, inputAmounts, 0, 1, true);

        vm.expectRevert(CraftingSystem.InvalidRecipe.selector);
        vm.prank(admin);
        craftingSystem.setRecipe(1, inputIds, inputAmounts, swordId, 0, true);
    }

    function testSetRecipeRejectsZeroInputFieldsAndDisableMissingRecipe() external {
        uint256[] memory inputIds = new uint256[](1);
        uint256[] memory inputAmounts = new uint256[](1);
        uint256 swordId = gameItems.SWORD();
        inputIds[0] = 0;
        inputAmounts[0] = 1;

        vm.expectRevert(CraftingSystem.InvalidRecipe.selector);
        vm.prank(admin);
        craftingSystem.setRecipe(1, inputIds, inputAmounts, swordId, 1, true);

        inputIds[0] = gameItems.WOOD();
        inputAmounts[0] = 0;

        vm.expectRevert(CraftingSystem.InvalidRecipe.selector);
        vm.prank(admin);
        craftingSystem.setRecipe(1, inputIds, inputAmounts, swordId, 1, true);

        vm.expectRevert(CraftingSystem.InvalidRecipe.selector);
        vm.prank(admin);
        craftingSystem.disableRecipe(999);
    }

    function testDisableRecipeAndRoleProtectedPauseUnpause() external {
        uint256[] memory inputIds = new uint256[](1);
        uint256[] memory inputAmounts = new uint256[](1);
        uint256 shieldId = gameItems.SHIELD();
        inputIds[0] = gameItems.WOOD();
        inputAmounts[0] = 2;

        vm.prank(admin);
        craftingSystem.setRecipe(2, inputIds, inputAmounts, shieldId, 1, true);

        vm.prank(admin);
        craftingSystem.disableRecipe(2);

        (,,,, bool active) = craftingSystem.getRecipe(2);
        assertFalse(active);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, outsider, craftingSystem.MANAGER_ROLE()
            )
        );
        vm.prank(outsider);
        craftingSystem.pause();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, outsider, craftingSystem.MANAGER_ROLE()
            )
        );
        vm.prank(outsider);
        craftingSystem.unpause();
    }
}
