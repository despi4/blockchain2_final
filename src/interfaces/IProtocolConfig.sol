// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IProtocolConfig {
    function marketplaceFeeBps() external view returns (uint256);
    function lootFeeBps() external view returns (uint256);
    function oracleHeartbeat(address asset) external view returns (uint256);
    function craftingEnabled(uint256 recipeId) external view returns (bool);
    function lootTableEnabled(uint256 tableId) external view returns (bool);
}
