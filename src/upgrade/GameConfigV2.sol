// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {GameConfigV1} from "./GameConfigV1.sol";

/// @title GameConfigV2
/// @notice V2 upgrade for GameConfig adding a per-day craft limit parameter.
contract GameConfigV2 is GameConfigV1 {
    uint256 public maxCraftPerDay;

    event MaxCraftPerDayUpdated(uint256 oldMaxCraftPerDay, uint256 newMaxCraftPerDay);

    /// @notice Updates the per-day crafting cap.
    function setMaxCraftPerDay(uint256 newMaxCraftPerDay) external onlyOwner {
        emit MaxCraftPerDayUpdated(maxCraftPerDay, newMaxCraftPerDay);
        maxCraftPerDay = newMaxCraftPerDay;
    }
}
