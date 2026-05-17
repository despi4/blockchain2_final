// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IResourcePool} from "../interfaces/IResourcePool.sol";

contract PoolQuoter {
    function quoteSwap(IResourcePool pool, address tokenIn, uint256 amountIn) external view returns (uint256) {
        return pool.quoteSwap(tokenIn, amountIn);
    }

    function quoteLiquidity(IResourcePool pool, uint256 lpAmount) external view returns (uint256 amount0, uint256 amount1) {
        (uint112 reserve0, uint112 reserve1) = pool.getReserves();
        uint256 supply = IERC20(address(pool)).totalSupply();
        amount0 = lpAmount * reserve0 / supply;
        amount1 = lpAmount * reserve1 / supply;
    }
}
