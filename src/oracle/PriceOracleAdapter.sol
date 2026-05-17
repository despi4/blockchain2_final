// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {L2SequencerGuard} from "./L2SequencerGuard.sol";

contract PriceOracleAdapter is Ownable, IPriceOracle {
    mapping(address asset => DataTypes.OracleFeedConfig config) public feedConfigs;
    L2SequencerGuard public sequencerGuard;

    event FeedConfigured(address indexed asset, address indexed feed, uint48 heartbeat, uint8 decimals, bool enabled);

    constructor(address initialOwner, L2SequencerGuard guard) Ownable(initialOwner) {
        sequencerGuard = guard;
    }

    function setSequencerGuard(L2SequencerGuard guard) external onlyOwner {
        sequencerGuard = guard;
    }

    function setFeed(address asset, address feed, uint48 heartbeat, bool enabled) external onlyOwner {
        uint8 feedDecimals = AggregatorV3Interface(feed).decimals();
        feedConfigs[asset] = DataTypes.OracleFeedConfig({
            feed: feed,
            heartbeat: heartbeat,
            decimals: feedDecimals,
            enabled: enabled
        });
        emit FeedConfigured(asset, feed, heartbeat, feedDecimals, enabled);
    }

    function getPrice(address asset) external view override returns (uint256 priceE18, uint256 updatedAt) {
        if (address(sequencerGuard) != address(0)) {
            sequencerGuard.ensureUp();
        }

        DataTypes.OracleFeedConfig memory config = feedConfigs[asset];
        if (!config.enabled || config.feed == address(0)) revert Errors.InvalidConfiguration();

        (, int256 answer,, uint256 timestamp, uint80 answeredInRound) =
            AggregatorV3Interface(config.feed).latestRoundData();
        if (answer <= 0) revert Errors.NegativePrice();
        if (answeredInRound == 0) revert Errors.InvalidConfiguration();
        if (block.timestamp - timestamp > config.heartbeat) revert Errors.StalePrice();

        uint256 unsignedAnswer = uint256(answer);
        if (config.decimals == 18) {
            return (unsignedAnswer, timestamp);
        }
        if (config.decimals < 18) {
            return (unsignedAnswer * 10 ** (18 - config.decimals), timestamp);
        }
        return (unsignedAnswer / 10 ** (config.decimals - 18), timestamp);
    }

    function isPriceFresh(address asset) external view override returns (bool) {
        DataTypes.OracleFeedConfig memory config = feedConfigs[asset];
        if (!config.enabled || config.feed == address(0)) {
            return false;
        }
        (, int256 answer,, uint256 timestamp,) = AggregatorV3Interface(config.feed).latestRoundData();
        if (answer <= 0) {
            return false;
        }
        if (address(sequencerGuard) != address(0)) {
            try sequencerGuard.ensureUp() {} catch {
                return false;
            }
        }
        return block.timestamp - timestamp <= config.heartbeat;
    }
}
