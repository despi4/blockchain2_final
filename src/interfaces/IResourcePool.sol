// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IResourcePool {
    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address to) external returns (uint256 amountOut);
    function addLiquidity(uint256 amount0, uint256 amount1, address to) external returns (uint256 liquidity);
    function removeLiquidity(uint256 liquidity, address to) external returns (uint256 amount0, uint256 amount1);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1);
    function quoteSwap(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut);
}
