// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ILootDropManager {
    function requestLoot(uint256 tableId) external returns (uint256 requestId);
    function fulfillLoot(uint256 requestId, uint256 randomness) external;
    function previewTable(uint256 tableId) external view returns (bytes memory summary);
}
