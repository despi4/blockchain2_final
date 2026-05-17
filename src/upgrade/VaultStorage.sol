// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

abstract contract VaultStorage {
    address internal _feeRecipient;
    uint256 internal _depositCap;
    uint256 internal _withdrawalFeeBps;
    uint256 internal _accruedFees;
    uint256[46] private __gap;
}
