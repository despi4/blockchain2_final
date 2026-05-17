// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {GameGovernanceToken} from "../../src/token/GameGovernanceToken.sol";

contract GameGovernanceTokenTest is Test {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint256 internal constant OWNER_PK = 0xA11CE;
    address internal owner = vm.addr(OWNER_PK);
    address internal treasury = makeAddr("treasury");
    address internal user = makeAddr("user");
    address internal spender = makeAddr("spender");

    GameGovernanceToken internal token;

    function setUp() external {
        token = new GameGovernanceToken(owner, treasury, 1_000_000 ether);
    }

    function testDeploymentMetadataAndRoles() external view {
        assertEq(token.name(), "Game Governance Token");
        assertEq(token.symbol(), "gGAME");
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(MINTER_ROLE, owner));
    }

    function testInitialSupplyMintedToTreasury() external view {
        assertEq(token.totalSupply(), 1_000_000 ether);
        assertEq(token.balanceOf(treasury), 1_000_000 ether);
    }

    function testAuthorizedMint() external {
        vm.prank(owner);
        token.mint(user, 250 ether);

        assertEq(token.balanceOf(user), 250 ether);
        assertEq(token.totalSupply(), 1_000_250 ether);
    }

    function testUnauthorizedMintReverts() external {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, MINTER_ROLE)
        );
        vm.prank(user);
        token.mint(user, 1 ether);
    }

    function testDelegationAndVotingPower() external {
        vm.prank(treasury);
        token.transfer(user, 500 ether);

        assertEq(token.getVotes(user), 0);

        vm.prank(user);
        token.delegate(user);

        assertEq(token.getVotes(user), 500 ether);
    }

    function testVotingPowerMovesAfterDelegation() external {
        vm.prank(treasury);
        token.transfer(user, 400 ether);

        vm.prank(user);
        token.delegate(user);
        assertEq(token.getVotes(user), 400 ether);

        vm.prank(user);
        token.transfer(spender, 150 ether);

        assertEq(token.getVotes(user), 250 ether);
    }

    function testPermit() external {
        uint256 value = 123 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = token.nonces(owner);

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        token.permit(owner, spender, value, deadline, v, r, s);

        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), nonce + 1);
    }
}
