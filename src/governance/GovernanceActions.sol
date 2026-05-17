// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ProtocolConfig} from "./ProtocolConfig.sol";

contract GovernanceActions is Ownable {
    ProtocolConfig public immutable protocolConfig;

    constructor(address initialOwner, ProtocolConfig protocolConfig_) Ownable(initialOwner) {
        protocolConfig = protocolConfig_;
    }

    function updateFeeConfig(uint256 marketplaceFeeBps, uint256 lootFeeBps) external onlyOwner {
        protocolConfig.setMarketplaceFeeBps(marketplaceFeeBps);
        protocolConfig.setLootFeeBps(lootFeeBps);
    }

    function updateFeatureFlags(uint256 recipeId, bool recipeEnabled, uint256 tableId, bool tableEnabled)
        external
        onlyOwner
    {
        protocolConfig.setCraftingEnabled(recipeId, recipeEnabled);
        protocolConfig.setLootTableEnabled(tableId, tableEnabled);
    }
}
