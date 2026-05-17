// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IProtocolConfig} from "../interfaces/IProtocolConfig.sol";

contract ProtocolConfig is Ownable, IProtocolConfig {
    uint256 public override marketplaceFeeBps;
    uint256 public override lootFeeBps;
    address public treasury;

    mapping(address asset => uint256 heartbeat) private _oracleHeartbeat;
    mapping(uint256 recipeId => bool enabled) private _craftingEnabled;
    mapping(uint256 tableId => bool enabled) private _lootTableEnabled;

    event MarketplaceFeeUpdated(uint256 feeBps);
    event LootFeeUpdated(uint256 feeBps);
    event TreasuryUpdated(address treasury);
    event OracleHeartbeatUpdated(address indexed asset, uint256 heartbeat);
    event CraftingToggled(uint256 indexed recipeId, bool enabled);
    event LootTableToggled(uint256 indexed tableId, bool enabled);

    constructor(address initialOwner, address treasury_, uint256 marketplaceFeeBps_, uint256 lootFeeBps_)
        Ownable(initialOwner)
    {
        treasury = treasury_;
        marketplaceFeeBps = marketplaceFeeBps_;
        lootFeeBps = lootFeeBps_;
    }

    function setMarketplaceFeeBps(uint256 feeBps) external onlyOwner {
        marketplaceFeeBps = feeBps;
        emit MarketplaceFeeUpdated(feeBps);
    }

    function setLootFeeBps(uint256 feeBps) external onlyOwner {
        lootFeeBps = feeBps;
        emit LootFeeUpdated(feeBps);
    }

    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    function setOracleHeartbeat(address asset, uint256 heartbeat) external onlyOwner {
        _oracleHeartbeat[asset] = heartbeat;
        emit OracleHeartbeatUpdated(asset, heartbeat);
    }

    function setCraftingEnabled(uint256 recipeId, bool enabled) external onlyOwner {
        _craftingEnabled[recipeId] = enabled;
        emit CraftingToggled(recipeId, enabled);
    }

    function setLootTableEnabled(uint256 tableId, bool enabled) external onlyOwner {
        _lootTableEnabled[tableId] = enabled;
        emit LootTableToggled(tableId, enabled);
    }

    function oracleHeartbeat(address asset) external view override returns (uint256) {
        return _oracleHeartbeat[asset];
    }

    function craftingEnabled(uint256 recipeId) external view override returns (bool) {
        return _craftingEnabled[recipeId];
    }

    function lootTableEnabled(uint256 tableId) external view override returns (bool) {
        return _lootTableEnabled[tableId];
    }
}
