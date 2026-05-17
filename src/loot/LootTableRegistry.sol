// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

contract LootTableRegistry is Ownable {
    mapping(uint256 tableId => DataTypes.LootEntry[] entries) private _tableEntries;
    mapping(uint256 tableId => DataTypes.LootTableConfig config) private _tableConfigs;

    event LootTableConfigured(uint256 indexed tableId, bool enabled, uint32 minRolls, uint32 maxRolls);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setLootTable(uint256 tableId, DataTypes.LootEntry[] calldata entries, DataTypes.LootTableConfig calldata config)
        external
        onlyOwner
    {
        delete _tableEntries[tableId];
        for (uint256 i = 0; i < entries.length; ++i) {
            _tableEntries[tableId].push(entries[i]);
        }
        _tableConfigs[tableId] = config;
        emit LootTableConfigured(tableId, config.enabled, config.minRolls, config.maxRolls);
    }

    function getLootTable(uint256 tableId)
        external
        view
        returns (DataTypes.LootEntry[] memory entries, DataTypes.LootTableConfig memory config)
    {
        return (_tableEntries[tableId], _tableConfigs[tableId]);
    }
}
