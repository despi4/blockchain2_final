// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library Errors {
    error ZeroAddress();
    error ZeroAmount();
    error Unauthorized();
    error InvalidAsset();
    error InvalidArrayLength();
    error InvalidConfiguration();
    error InvalidListing();
    error InvalidRental();
    error AlreadyProcessed();
    error NotExpired();
    error Expired();
    error Disabled();
    error SlippageExceeded();
    error InsufficientLiquidity();
    error PoolExists();
    error PoolNotFound();
    error UnsupportedToken();
    error StalePrice();
    error NegativePrice();
    error SequencerDown();
    error GracePeriodNotElapsed();
    error RequestNotFound();
    error AlreadyFulfilled();
    error UpgradeDenied();
}
