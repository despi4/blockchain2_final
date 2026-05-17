// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IResourcePool} from "../interfaces/IResourcePool.sol";

contract ResourceRouter {
    function addLiquidity(IResourcePool pool, uint256 amount0, uint256 amount1, address to) external returns (uint256) {
        return pool.addLiquidity(amount0, amount1, to);
    }

    function removeLiquidity(IResourcePool pool, uint256 liquidity, address to)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        return pool.removeLiquidity(liquidity, to);
    }

    function swap(IResourcePool pool, address tokenIn, uint256 amountIn, uint256 minAmountOut, address to)
        external
        returns (uint256 amountOut)
    {
        return pool.swap(tokenIn, amountIn, minAmountOut, to);
    }
}
