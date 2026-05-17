// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../../src/governance/GameFiGovernor.sol";
import "../../src/governance/GameFiTimelock.sol";

// Minimal ERC20Votes token for testing (matches what Person 1 deploys)
contract MockGovToken is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("GameFi Token", "GFI") ERC20Permit("GameFi Token") {
        _mint(msg.sender, 1_000_000e18);
    }
    function _update(address from, address to, uint256 value)
        internal override(ERC20, ERC20Votes)
    { super._update(from, to, value); }
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}

// Simple target contract governed by DAO (simulates GameFi parameter store)
contract GameParams {
    uint256 public dropRate = 100;
    uint256 public craftingCost = 50;
    address public timelockAddr;

    constructor(address _timelock) { timelockAddr = _timelock; }

    modifier onlyTimelock() {
        require(msg.sender == timelockAddr, "only timelock");
        _;
    }

    function setDropRate(uint256 rate) external onlyTimelock { dropRate = rate; }
    function setCraftingCost(uint256 cost) external onlyTimelock { craftingCost = cost; }
}

contract GovernorTest is Test {
    MockGovToken   token;
    GameFiTimelock timelock;
    GameFiGovernor governor;
    GameParams     params;

    address proposer = makeAddr("proposer");
    address voter1   = makeAddr("voter1");
    address voter2   = makeAddr("voter2");

    // Block counts matching governor settings
    uint256 constant VOTING_DELAY  = 7_200;
    uint256 constant VOTING_PERIOD = 50_400;

    function setUp() public {
        vm.roll(1); // start at block 1

        token = new MockGovToken();
        token.transfer(proposer, 10_000e18);
        token.transfer(voter1,   400_000e18);
        token.transfer(voter2,   300_000e18);

        // Delegate to activate voting power (must happen before roll)
        vm.prank(proposer); token.delegate(proposer);
        vm.prank(voter1);   token.delegate(voter1);
        vm.prank(voter2);   token.delegate(voter2);

        // Deploy timelock with temporary proposer, then swap
        timelock = new GameFiTimelock(address(1));
        governor = new GameFiGovernor(IVotes(address(token)), timelock);

        vm.startPrank(address(timelock));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.revokeRole(timelock.PROPOSER_ROLE(), address(1));
        vm.stopPrank();

        params = new GameParams(address(timelock));

        // Roll forward so delegation checkpoints are in the past
        vm.roll(block.number + 1);
    }

    // ── Unit tests ────────────────────────────────────────────────────────────

    function test_governor_name() public view {
        assertEq(governor.name(), "GameFiGovernor");
    }

    function test_voting_delay_approx_1day() public view {
        assertEq(governor.votingDelay(), 7_200);
    }

    function test_voting_period_approx_1week() public view {
        assertEq(governor.votingPeriod(), 50_400);
    }

    function test_quorum_fraction_4pct() public view {
        assertEq(governor.quorumNumerator(), 4);
    }

    function test_timelock_min_delay_2days() public view {
        assertEq(timelock.getMinDelay(), 2 days);
    }

    function test_proposal_threshold_1pct_of_supply() public view {
        // 1% of 1_000_000e18 = 10_000e18; proposer has exactly that
        assertEq(governor.proposalThreshold(), 10_000e18);
        assertGe(token.balanceOf(proposer), governor.proposalThreshold());
    }

    function test_voting_power_after_delegation() public view {
        assertGt(governor.getVotes(voter1, block.number - 1), 0);
        assertGt(governor.getVotes(voter2, block.number - 1), 0);
    }

    function test_timelock_is_governor_proposer() public view {
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
    }

    function test_no_admin_backdoor() public view {
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)));
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(governor)));
    }

    function test_params_owner_is_timelock() public view {
        assertEq(params.timelockAddr(), address(timelock));
    }

    // ── Full lifecycle: propose → vote → queue → execute ─────────────────────

    function test_full_governance_lifecycle() public {
        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = address(params);
        calldatas[0] = abi.encodeCall(GameParams.setDropRate, (200));
        string memory description  = "Proposal #1: Double the drop rate";

        // Propose
        vm.prank(proposer);
        uint256 pid = governor.propose(targets, values, calldatas, description);
        assertEq(uint8(governor.state(pid)), 0); // Pending

        // Advance past voting delay
        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint8(governor.state(pid)), 1); // Active

        // Both voters cast For
        vm.prank(voter1); governor.castVote(pid, 1);
        vm.prank(voter2); governor.castVote(pid, 1);

        // Advance past voting period
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint8(governor.state(pid)), 4); // Succeeded

        // Queue in timelock
        bytes32 descHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descHash);
        assertEq(uint8(governor.state(pid)), 5); // Queued

        // Advance past timelock delay (2 days in seconds)
        vm.warp(block.timestamp + 2 days + 1);

        // Execute — timelock calls params.setDropRate(200)
        governor.execute(targets, values, calldatas, descHash);
        assertEq(uint8(governor.state(pid)), 7); // Executed
        assertEq(params.dropRate(), 200);
    }

    function test_proposal_defeated_when_quorum_not_met() public {
        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = address(params);
        calldatas[0] = abi.encodeCall(GameParams.setDropRate, (50));

        vm.prank(proposer);
        uint256 pid = governor.propose(targets, values, calldatas, "Lower drop rate");

        vm.roll(block.number + VOTING_DELAY + 1);

        // Proposer votes: 10_000e18 / 1_000_000e18 = 1%, below 4% quorum
        vm.prank(proposer); governor.castVote(pid, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint8(governor.state(pid)), 3); // Defeated (quorum not met)
    }

    function test_cannot_vote_twice() public {
        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = address(params);
        calldatas[0] = abi.encodeCall(GameParams.setDropRate, (150));

        vm.prank(proposer);
        uint256 pid = governor.propose(targets, values, calldatas, "Medium rate");

        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voter1); governor.castVote(pid, 1);

        vm.prank(voter1);
        vm.expectRevert();
        governor.castVote(pid, 0);
    }

    function test_cannot_propose_below_threshold() public {
        address lowStake = makeAddr("lowStake");
        token.transfer(lowStake, 5_000e18); // 0.5% — below 1% threshold
        vm.prank(lowStake); token.delegate(lowStake);
        vm.roll(block.number + 1);

        address[] memory t = new address[](1);
        uint256[] memory v = new uint256[](1);
        bytes[]   memory c = new bytes[](1);
        t[0] = address(params);
        c[0] = abi.encodeCall(GameParams.setDropRate, (999));

        vm.prank(lowStake);
        vm.expectRevert();
        governor.propose(t, v, c, "Spam proposal");
    }

    function test_against_votes_defeat_proposal() public {
        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = address(params);
        calldatas[0] = abi.encodeCall(GameParams.setCraftingCost, (999));

        vm.prank(proposer);
        uint256 pid = governor.propose(targets, values, calldatas, "High crafting cost");

        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voter1); governor.castVote(pid, 0); // Against
        vm.prank(voter2); governor.castVote(pid, 0); // Against
        vm.prank(proposer); governor.castVote(pid, 1); // For (minority)

        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint8(governor.state(pid)), 3); // Defeated
    }

    // ── Fuzz test ─────────────────────────────────────────────────────────────

    function testFuzz_voting_power_equals_balance(uint96 seed, uint96 amount) public {
        address user = address(uint160(uint256(keccak256(abi.encode(seed, "fuzz_user")))));
        vm.assume(user != proposer && user != voter1 && user != voter2 && user != address(this));
        vm.assume(token.balanceOf(user) == 0); // ensure clean slate

        uint256 amt = bound(uint256(amount), 1e18, 50_000e18);
        token.transfer(user, amt);
        vm.prank(user); token.delegate(user);
        vm.roll(block.number + 1);

        assertEq(governor.getVotes(user, block.number - 1), amt);
    }
}
