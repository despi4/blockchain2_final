// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GameGovernanceToken} from "../../src/token/GameGovernanceToken.sol";
import {GameGovernor} from "../../src/governance/GameGovernor.sol";
import {GovernanceActions} from "../../src/governance/GovernanceActions.sol";
import {ProtocolConfig} from "../../src/governance/ProtocolConfig.sol";

contract GovernorBox {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
    }
}

contract GovernanceSupportTest is Test {
    address internal owner = makeAddr("owner");
    address internal proposer = makeAddr("proposer");
    address internal voter = makeAddr("voter");
    address internal treasury = makeAddr("treasury");
    address internal outsider = makeAddr("outsider");

    function testProtocolConfigOwnerSettersAndGetters() external {
        ProtocolConfig config = new ProtocolConfig(owner, treasury, 30, 15);

        vm.startPrank(owner);
        config.setMarketplaceFeeBps(50);
        config.setLootFeeBps(20);
        config.setTreasury(proposer);
        config.setOracleHeartbeat(address(0xBEEF), 1 hours);
        config.setCraftingEnabled(1, true);
        config.setLootTableEnabled(7, true);
        vm.stopPrank();

        assertEq(config.marketplaceFeeBps(), 50);
        assertEq(config.lootFeeBps(), 20);
        assertEq(config.treasury(), proposer);
        assertEq(config.oracleHeartbeat(address(0xBEEF)), 1 hours);
        assertTrue(config.craftingEnabled(1));
        assertTrue(config.lootTableEnabled(7));
    }

    function testProtocolConfigRejectsUnauthorizedSetters() external {
        ProtocolConfig config = new ProtocolConfig(owner, treasury, 30, 15);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        vm.prank(outsider);
        config.setMarketplaceFeeBps(99);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        vm.prank(outsider);
        config.setLootFeeBps(99);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        vm.prank(outsider);
        config.setTreasury(outsider);
    }

    function testGovernanceActionsCanDriveProtocolConfigOnceOwnershipTransferred() external {
        ProtocolConfig config = new ProtocolConfig(owner, treasury, 30, 15);
        GovernanceActions actions = new GovernanceActions(owner, config);

        vm.prank(owner);
        config.transferOwnership(address(actions));

        vm.prank(owner);
        actions.updateFeeConfig(45, 25);

        vm.prank(owner);
        actions.updateFeatureFlags(3, true, 5, true);

        assertEq(config.marketplaceFeeBps(), 45);
        assertEq(config.lootFeeBps(), 25);
        assertTrue(config.craftingEnabled(3));
        assertTrue(config.lootTableEnabled(5));
    }

    function testGovernanceActionsRejectUnauthorizedCaller() external {
        ProtocolConfig config = new ProtocolConfig(owner, treasury, 30, 15);
        GovernanceActions actions = new GovernanceActions(owner, config);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        vm.prank(outsider);
        actions.updateFeeConfig(1, 2);
    }

    function testGameGovernorLifecycleAndViews() external {
        GameGovernanceToken token = new GameGovernanceToken(owner, owner, 1_000_000 ether);

        vm.prank(owner);
        token.transfer(proposer, 200_000 ether);
        vm.prank(owner);
        token.transfer(voter, 200_000 ether);

        vm.prank(proposer);
        token.delegate(proposer);
        vm.prank(voter);
        token.delegate(voter);

        address[] memory proposers = new address[](1);
        proposers[0] = owner;
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        TimelockController timelock = new TimelockController(1 days, proposers, executors, owner);
        GameGovernor governor = new GameGovernor(token, timelock);

        vm.startPrank(owner);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.revokeRole(timelock.PROPOSER_ROLE(), owner);
        vm.stopPrank();

        vm.roll(block.number + 1);

        GovernorBox box = new GovernorBox();
        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(GovernorBox.setValue, (77));
        string memory description = "set value to 77";

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        assertEq(governor.votingDelay(), 7200);
        assertEq(governor.votingPeriod(), 50400);
        assertEq(governor.proposalThreshold(), 100 ether);
        assertEq(governor.quorum(block.number - 1), 40_000 ether);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
        assertTrue(governor.supportsInterface(type(IERC165).interfaceId));

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(proposer);
        governor.castVote(proposalId, 1);
        vm.prank(voter);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));
        assertTrue(governor.proposalNeedsQueuing(proposalId));

        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        vm.warp(block.timestamp + 1 days + 1);
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(box.value(), 77);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
    }

    function testGameGovernorCancelPath() external {
        GameGovernanceToken token = new GameGovernanceToken(owner, owner, 1_000_000 ether);

        vm.prank(owner);
        token.transfer(proposer, 200 ether);
        vm.prank(proposer);
        token.delegate(proposer);

        address[] memory proposers = new address[](1);
        proposers[0] = owner;
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        TimelockController timelock = new TimelockController(1 days, proposers, executors, owner);
        GameGovernor governor = new GameGovernor(token, timelock);

        vm.startPrank(owner);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.revokeRole(timelock.PROPOSER_ROLE(), owner);
        vm.stopPrank();

        vm.roll(block.number + 1);

        GovernorBox box = new GovernorBox();
        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(GovernorBox.setValue, (11));
        bytes32 descriptionHash = keccak256(bytes("cancel me"));

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "cancel me");

        vm.prank(proposer);
        token.transfer(owner, 101 ether);
        vm.roll(block.number + 1);

        vm.prank(proposer);
        governor.cancel(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }
}
