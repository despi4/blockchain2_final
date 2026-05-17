// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {GameFiGovernor} from "../../src/governance/GameFiGovernor.sol";
import {GameFiTimelock} from "../../src/governance/GameFiTimelock.sol";
import {GameGovernanceToken} from "../../src/token/GameGovernanceToken.sol";

contract GameFiGovernorBox {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
    }
}

contract GameFiGovernorAdditionalTest is Test {
    address internal proposer = makeAddr("proposer");
    address internal voter = makeAddr("voter");

    GameGovernanceToken internal token;
    GameFiTimelock internal timelock;
    GameFiGovernor internal governor;

    function setUp() external {
        token = new GameGovernanceToken(address(this), address(this), 1_000_000 ether);
        token.transfer(proposer, 50_000 ether);
        token.transfer(voter, 400_000 ether);

        vm.prank(proposer);
        token.delegate(proposer);
        vm.prank(voter);
        token.delegate(voter);

        timelock = new GameFiTimelock(address(1));
        governor = new GameFiGovernor(IVotes(address(token)), timelock);

        vm.startPrank(address(timelock));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.revokeRole(timelock.PROPOSER_ROLE(), address(1));
        vm.stopPrank();

        vm.roll(block.number + 1);
    }

    function testViewsAndProposalNeedsQueuing() external {
        GameFiGovernorBox box = new GameFiGovernorBox();
        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(GameFiGovernorBox.setValue, (55));
        string memory description = "set to 55";
        bytes32 descriptionHash = keccak256(bytes(description));

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        assertEq(governor.quorum(block.number - 1), 40_000 ether);

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(proposer);
        governor.castVote(proposalId, 1);
        vm.prank(voter);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);
        assertTrue(governor.proposalNeedsQueuing(proposalId));

        governor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + 2 days + 1);
        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(box.value(), 55);
    }

    function testCancelPath() external {
        GameFiGovernorBox box = new GameFiGovernorBox();
        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(GameFiGovernorBox.setValue, (99));
        bytes32 descriptionHash = keccak256(bytes("cancel old proposal"));

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "cancel old proposal");

        vm.prank(proposer);
        token.transfer(voter, 45_000 ether);
        vm.roll(block.number + 1);

        vm.prank(proposer);
        governor.cancel(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }
}
