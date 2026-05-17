// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title GameMath
/// @notice Pure Solidity math helpers for GameFi fee and utility calculations.
contract GameMath {
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Calculates a fee in basis points using checked Solidity arithmetic.
    /// @param amount Base amount to charge the fee on.
    /// @param feeBps Fee in basis points.
    /// @return fee The calculated fee amount.
    function calculateFeeSolidity(uint256 amount, uint256 feeBps) external pure returns (uint256 fee) {
        fee = amount * feeBps / BPS_DENOMINATOR;
    }

    /// @notice Returns the minimum of two values.
    function min(uint256 a, uint256 b) external pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Returns the integer square root of a value, rounded down.
    function sqrt(uint256 x) external pure returns (uint256) {
        return Math.sqrt(x);
    }
}
