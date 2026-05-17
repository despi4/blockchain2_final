// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ILootDropManager} from "../interfaces/ILootDropManager.sol";
import {IProtocolConfig} from "../interfaces/IProtocolConfig.sol";
import {IGameItems1155} from "../interfaces/IGameItems1155.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {LootTableRegistry} from "./LootTableRegistry.sol";
import {VRFAdapter} from "./VRFAdapter.sol";
import {IVRFConsumer} from "./interfaces/IVRFConsumer.sol";

contract LootDropManager is ILootDropManager, AccessControl, IVRFConsumer {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    struct LootRequest {
        address user;
        uint256 tableId;
        bool fulfilled;
    }

    IGameItems1155 public immutable items;
    IProtocolConfig public immutable protocolConfig;
    LootTableRegistry public immutable lootTableRegistry;
    VRFAdapter public immutable vrfAdapter;

    mapping(uint256 requestId => LootRequest request) public requests;

    event LootRequested(uint256 indexed requestId, address indexed user, uint256 indexed tableId);
    event LootFulfilled(uint256 indexed requestId, address indexed user, uint256 indexed itemId, uint256 amount);

    constructor(
        address admin,
        IGameItems1155 items_,
        IProtocolConfig protocolConfig_,
        LootTableRegistry lootTableRegistry_,
        VRFAdapter vrfAdapter_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        items = items_;
        protocolConfig = protocolConfig_;
        lootTableRegistry = lootTableRegistry_;
        vrfAdapter = vrfAdapter_;
    }

    function requestLoot(uint256 tableId) external override returns (uint256 requestId) {
        if (!protocolConfig.lootTableEnabled(tableId)) revert Errors.Disabled();
        requestId = vrfAdapter.requestRandomness();
        requests[requestId] = LootRequest({user: msg.sender, tableId: tableId, fulfilled: false});
        emit LootRequested(requestId, msg.sender, tableId);
    }

    function fulfillLoot(uint256 requestId, uint256 randomness) external override onlyRole(OPERATOR_ROLE) {
        _fulfill(requestId, randomness);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external override {
        if (msg.sender != address(vrfAdapter)) revert Errors.Unauthorized();
        _fulfill(requestId, randomWords[0]);
    }

    function previewTable(uint256 tableId) external view override returns (bytes memory summary) {
        (DataTypes.LootEntry[] memory entries, DataTypes.LootTableConfig memory config) = lootTableRegistry.getLootTable(tableId);
        return abi.encode(config, entries);
    }

    function _fulfill(uint256 requestId, uint256 randomness) internal {
        LootRequest storage request = requests[requestId];
        if (request.user == address(0)) revert Errors.RequestNotFound();
        if (request.fulfilled) revert Errors.AlreadyFulfilled();

        (DataTypes.LootEntry[] memory entries, DataTypes.LootTableConfig memory config) = lootTableRegistry.getLootTable(request.tableId);
        if (!config.enabled || entries.length == 0) revert Errors.Disabled();

        request.fulfilled = true;

        uint256 totalWeight;
        for (uint256 i = 0; i < entries.length; ++i) {
            totalWeight += entries[i].weight;
        }

        uint256 roll = randomness % totalWeight;
        uint256 cumulative;
        for (uint256 i = 0; i < entries.length; ++i) {
            cumulative += entries[i].weight;
            if (roll < cumulative) {
                items.mint(request.user, entries[i].itemId, entries[i].amount, "");
                emit LootFulfilled(requestId, request.user, entries[i].itemId, entries[i].amount);
                return;
            }
        }

        revert Errors.InvalidConfiguration();
    }
}
