// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Errors} from "./Errors.sol";

library ValidationLib {
    function requireNonZero(address account) internal pure {
        if (account == address(0)) revert Errors.ZeroAddress();
    }

    function requireAmount(uint256 amount) internal pure {
        if (amount == 0) revert Errors.ZeroAmount();
    }

    function requireMatchingLengths(uint256 expected, uint256 actual) internal pure {
        if (expected != actual) revert Errors.InvalidArrayLength();
    }
}
