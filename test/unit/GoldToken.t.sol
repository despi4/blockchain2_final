// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {IronToken} from "../../src/token/IronToken.sol";
import {WoodToken} from "../../src/token/WoodToken.sol";

contract GoldTokenTest is Test {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address internal admin = makeAddr("admin");
    address internal treasury = makeAddr("treasury");
    address internal user = makeAddr("user");

    GoldToken internal gold;

    function setUp() external {
        gold = new GoldToken(admin, treasury, 500_000 ether);
    }

    function testDeployment() external view {
        assertEq(gold.name(), "Gold Token");
        assertEq(gold.symbol(), "GOLD");
        assertTrue(gold.hasRole(gold.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(gold.hasRole(MINTER_ROLE, admin));
    }

    function testInitialSupply() external view {
        assertEq(gold.totalSupply(), 500_000 ether);
        assertEq(gold.balanceOf(treasury), 500_000 ether);
    }

    function testMintAccessControl() external {
        vm.prank(admin);
        gold.mint(user, 50 ether);

        assertEq(gold.balanceOf(user), 50 ether);
    }

    function testUnauthorizedMintReverts() external {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, MINTER_ROLE)
        );
        vm.prank(user);
        gold.mint(user, 1 ether);
    }

    function testBurnByHolder() external {
        vm.prank(treasury);
        gold.transfer(user, 100 ether);

        vm.prank(user);
        gold.burn(40 ether);

        assertEq(gold.balanceOf(user), 60 ether);
        assertEq(gold.totalSupply(), 500_000 ether - 40 ether);
    }

    function testOptionalResourceTokensDeploy() external {
        WoodToken wood = new WoodToken(admin, treasury, 1_000 ether);
        IronToken iron = new IronToken(admin, treasury, 2_000 ether);

        assertEq(wood.symbol(), "WOOD");
        assertEq(iron.symbol(), "IRON");
        assertEq(wood.balanceOf(treasury), 1_000 ether);
        assertEq(iron.balanceOf(treasury), 2_000 ether);
    }
}
