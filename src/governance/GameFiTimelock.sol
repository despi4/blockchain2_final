// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title GameFiTimelock
/// @notice 2-day timelock that guards all DAO-governed protocol parameters.
///         The Governor is the only proposer; the zero address is executor (anyone can execute after delay).
///         The Timelock itself is the admin (no backdoor).
contract GameFiTimelock is TimelockController {
    uint256 public constant MIN_DELAY = 2 days;

    constructor(address governor)
        TimelockController(
            MIN_DELAY,
            _proposers(governor),
            _executors(),
            address(0) // admin = zero → Timelock self-admins; no external admin backdoor
        )
    {}

    // ── Helpers for constructor args ──────────────────────────────────────────

    function _proposers(address governor) private pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = governor;
    }

    function _executors() private pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = address(0); // zero address = anyone can execute after delay
    }
}
