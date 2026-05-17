// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {Errors} from "../libraries/Errors.sol";

contract L2SequencerGuard is Ownable {
    AggregatorV3Interface public sequencerUptimeFeed;
    uint256 public gracePeriod;

    constructor(address initialOwner, AggregatorV3Interface feed, uint256 gracePeriod_) Ownable(initialOwner) {
        sequencerUptimeFeed = feed;
        gracePeriod = gracePeriod_;
    }

    function setSequencerFeed(AggregatorV3Interface feed) external onlyOwner {
        sequencerUptimeFeed = feed;
    }

    function setGracePeriod(uint256 newGracePeriod) external onlyOwner {
        gracePeriod = newGracePeriod;
    }

    function ensureUp() public view {
        (, int256 answer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();
        if (answer != 0) revert Errors.SequencerDown();
        if (block.timestamp - startedAt <= gracePeriod) revert Errors.GracePeriodNotElapsed();
    }
}
