// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title GameMathYul
/// @notice Inline Yul implementations used to benchmark against pure Solidity equivalents.
contract GameMathYul {
    uint256 public constant BPS_DENOMINATOR = 10_000;

    error MultiplicationOverflow();

    /// @notice Calculates a fee in basis points using inline Yul.
    /// @dev Reverts on multiplication overflow to match Solidity 0.8 checked arithmetic.
    /// @param amount Base amount to charge the fee on.
    /// @param feeBps Fee in basis points.
    /// @return fee The calculated fee amount.
    function calculateFeeYul(uint256 amount, uint256 feeBps) external pure returns (uint256 fee) {
        assembly {
            if and(iszero(iszero(feeBps)), gt(amount, div(not(0), feeBps))) {
                mstore(0x00, shl(224, 0xd7cb015e))
                revert(0x00, 0x04)
            }

            fee := div(mul(amount, feeBps), 10000)
        }
    }

    /// @notice Returns the minimum of two values using inline Yul.
    function minYul(uint256 a, uint256 b) external pure returns (uint256 result) {
        assembly {
            result := xor(a, mul(xor(a, b), lt(b, a)))
        }
    }
}
