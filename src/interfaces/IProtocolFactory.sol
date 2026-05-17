// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IProtocolFactory {
    function createPool(address tokenA, address tokenB) external returns (address pool);
    function createPoolDeterministic(address tokenA, address tokenB, bytes32 salt) external returns (address pool);
    function predictPoolAddress(address tokenA, address tokenB, bytes32 salt) external view returns (address predicted);
    function getPool(address tokenA, address tokenB) external view returns (address pool);
}
