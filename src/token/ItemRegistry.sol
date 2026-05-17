// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

contract ItemRegistry is AccessControl {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    mapping(uint256 itemId => DataTypes.ItemConfig config) private _itemConfigs;

    event ItemConfigured(uint256 indexed itemId, DataTypes.ItemCategory category, bool craftable, bool lootable, bool rentable);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(REGISTRAR_ROLE, admin);
    }

    function setItemConfig(uint256 itemId, DataTypes.ItemConfig calldata config) external onlyRole(REGISTRAR_ROLE) {
        _itemConfigs[itemId] = config;
        emit ItemConfigured(itemId, config.category, config.craftable, config.lootable, config.rentable);
    }

    function getItemConfig(uint256 itemId) external view returns (DataTypes.ItemConfig memory) {
        return _itemConfigs[itemId];
    }
}
