// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IProtocolFactory {
    function deployPool(address token0, address token1) external returns (address pool);
    function deployPoolDeterministic(address token0, address token1, bytes32 salt) external returns (address pool);
    function predictPoolAddress(address token0, address token1, bytes32 salt) external view returns (address predicted);
}
