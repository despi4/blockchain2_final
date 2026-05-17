// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

/// @title PriceOracle
/// @notice Minimal Chainlink price feed wrapper with freshness checks for GameFi pricing.
contract PriceOracle is Ownable {
    /// @notice Reverts when the configured feed address is zero.
    error InvalidFeed();

    /// @notice Reverts when the feed returns a zero or negative price.
    error InvalidPrice();

    /// @notice Reverts when the feed update timestamp is zero.
    error InvalidTimestamp();

    /// @notice Reverts when the price is older than the allowed staleness threshold.
    error StalePrice(uint256 updatedAt, uint256 currentTimestamp, uint256 maxStaleness);

    /// @notice Active Chainlink-compatible price feed.
    AggregatorV3Interface public feed;

    /// @notice Maximum accepted age for the reported price, in seconds.
    uint256 public maxStaleness;

    /// @notice Emitted when the feed address is updated.
    event FeedUpdated(address indexed oldFeed, address indexed newFeed);

    /// @notice Emitted when the staleness threshold is updated.
    event MaxStalenessUpdated(uint256 oldMaxStaleness, uint256 newMaxStaleness);

    /// @param initialOwner Owner allowed to manage feed configuration.
    /// @param feed_ Chainlink-compatible feed contract.
    /// @param maxStaleness_ Maximum accepted age for price data in seconds.
    constructor(address initialOwner, AggregatorV3Interface feed_, uint256 maxStaleness_) Ownable(initialOwner) {
        _setFeed(feed_);
        _setMaxStaleness(maxStaleness_);
    }

    /// @notice Returns the latest validated price in the feed's native decimals.
    /// @return price Latest positive price returned by the feed.
    /// @return updatedAt Timestamp of the feed update used for the price.
    function getLatestPrice() external view returns (uint256 price, uint256 updatedAt) {
        return _readPrice();
    }

    /// @notice Returns the latest validated price normalized to 18 decimals.
    /// @return price18 Latest positive price scaled to 18 decimals.
    /// @return updatedAt Timestamp of the feed update used for the price.
    function getLatestPrice18Decimals() external view returns (uint256 price18, uint256 updatedAt) {
        (uint256 price, uint256 timestamp) = _readPrice();
        uint8 decimals = feed.decimals();

        if (decimals == 18) {
            return (price, timestamp);
        }
        if (decimals < 18) {
            return (price * 10 ** (18 - decimals), timestamp);
        }
        return (price / 10 ** (decimals - 18), timestamp);
    }

    /// @notice Updates the accepted staleness threshold.
    /// @param newMaxStaleness New threshold in seconds.
    function setMaxStaleness(uint256 newMaxStaleness) external onlyOwner {
        uint256 oldMaxStaleness = maxStaleness;
        _setMaxStaleness(newMaxStaleness);
        emit MaxStalenessUpdated(oldMaxStaleness, newMaxStaleness);
    }

    /// @notice Updates the price feed address.
    /// @param newFeed New Chainlink-compatible feed.
    function setFeed(AggregatorV3Interface newFeed) external onlyOwner {
        address oldFeed = address(feed);
        _setFeed(newFeed);
        emit FeedUpdated(oldFeed, address(newFeed));
    }

    function _readPrice() internal view returns (uint256 price, uint256 updatedAt) {
        (, int256 answer,, uint256 timestamp,) = feed.latestRoundData();
        if (answer <= 0) revert InvalidPrice();
        if (timestamp == 0) revert InvalidTimestamp();
        if (block.timestamp - timestamp > maxStaleness) {
            revert StalePrice(timestamp, block.timestamp, maxStaleness);
        }

        return (uint256(answer), timestamp);
    }

    function _setFeed(AggregatorV3Interface newFeed) internal {
        if (address(newFeed) == address(0)) revert InvalidFeed();
        feed = newFeed;
    }

    function _setMaxStaleness(uint256 newMaxStaleness) internal {
        if (newMaxStaleness == 0) revert InvalidTimestamp();
        maxStaleness = newMaxStaleness;
    }
}
