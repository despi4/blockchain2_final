// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {GameItems} from "../../src/token/GameItems.sol";

contract GameItemsTest is Test {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 internal constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");

    address internal admin = makeAddr("admin");
    address internal user = makeAddr("user");
    address internal minter = makeAddr("minter");
    address internal burner = makeAddr("burner");
    address internal uriSetter = makeAddr("uriSetter");

    GameItems internal items;
    uint256 internal woodId;
    uint256 internal stoneId;
    uint256 internal ironId;
    uint256 internal swordId;
    uint256 internal shieldId;
    uint256 internal rareChestId;
    uint256 internal legendaryItemId;

    function setUp() external {
        items = new GameItems(admin, "ipfs://game-items/");
        woodId = items.WOOD();
        stoneId = items.STONE();
        ironId = items.IRON();
        swordId = items.SWORD();
        shieldId = items.SHIELD();
        rareChestId = items.RARE_CHEST();
        legendaryItemId = items.LEGENDARY_ITEM();

        vm.startPrank(admin);
        items.grantRole(MINTER_ROLE, minter);
        items.grantRole(BURNER_ROLE, burner);
        items.grantRole(URI_SETTER_ROLE, uriSetter);
        vm.stopPrank();
    }

    function testAdminHasRoles() external view {
        assertTrue(items.hasRole(items.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(items.hasRole(MINTER_ROLE, admin));
        assertTrue(items.hasRole(BURNER_ROLE, admin));
        assertTrue(items.hasRole(URI_SETTER_ROLE, admin));
    }

    function testMinterCanMint() external {
        vm.prank(minter);
        items.mint(user, woodId, 10, "");

        assertEq(items.balanceOf(user, woodId), 10);
    }

    function testNonMinterCannotMint() external {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, MINTER_ROLE)
        );
        vm.prank(user);
        items.mint(user, woodId, 1, "");
    }

    function testBurnerCanBurn() external {
        vm.prank(minter);
        items.mint(user, stoneId, 10, "");

        vm.prank(burner);
        items.burn(user, stoneId, 4);

        assertEq(items.balanceOf(user, stoneId), 6);
    }

    function testNonBurnerCannotBurn() external {
        vm.prank(minter);
        items.mint(user, ironId, 5, "");

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, BURNER_ROLE)
        );
        vm.prank(user);
        items.burn(user, ironId, 1);
    }

    function testBatchMintWorks() external {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = woodId;
        ids[1] = stoneId;
        ids[2] = ironId;
        amounts[0] = 25;
        amounts[1] = 15;
        amounts[2] = 5;

        vm.prank(minter);
        items.mintBatch(user, ids, amounts, "");

        assertEq(items.balanceOf(user, ids[0]), amounts[0]);
        assertEq(items.balanceOf(user, ids[1]), amounts[1]);
        assertEq(items.balanceOf(user, ids[2]), amounts[2]);
    }

    function testBatchBurnWorks() external {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = swordId;
        ids[1] = shieldId;
        amounts[0] = 3;
        amounts[1] = 2;

        vm.prank(minter);
        items.mintBatch(user, ids, amounts, "");

        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 1;
        burnAmounts[1] = 2;

        vm.prank(burner);
        items.burnBatch(user, ids, burnAmounts);

        assertEq(items.balanceOf(user, ids[0]), 2);
        assertEq(items.balanceOf(user, ids[1]), 0);
    }

    function testURICanBeUpdatedOnlyByRole() external {
        vm.prank(uriSetter);
        items.setTokenURI(rareChestId, "rare-chest.json");

        assertEq(items.uri(rareChestId), "ipfs://game-items/rare-chest.json");

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, URI_SETTER_ROLE)
        );
        vm.prank(user);
        items.setTokenURI(legendaryItemId, "legendary-item.json");
    }

    function testSupportsInterfaceWorksForERC1155AndAccessControl() external view {
        assertTrue(items.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(items.supportsInterface(type(IAccessControl).interfaceId));
    }
}
