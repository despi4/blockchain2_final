// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library ResourceMath {
    function quoteLiquidity(uint256 amount0, uint256 amount1, uint112 reserve0, uint112 reserve1)
        internal
        pure
        returns (uint256 liquidity)
    {
        if (reserve0 == 0 && reserve1 == 0) {
            return Math.sqrt(amount0 * amount1);
        }
        uint256 liquidity0 = amount0 * totalLiquidity(reserve0, reserve1) / reserve0;
        uint256 liquidity1 = amount1 * totalLiquidity(reserve0, reserve1) / reserve1;
        return Math.min(liquidity0, liquidity1);
    }

    function getAmountOut(uint256 amountIn, uint112 reserveIn, uint112 reserveOut, uint256 feeBps)
        internal
        pure
        returns (uint256)
    {
        uint256 amountInWithFee = amountIn * (10_000 - feeBps);
        return (amountInWithFee * reserveOut) / (uint256(reserveIn) * 10_000 + amountInWithFee);
    }

    function totalLiquidity(uint112 reserve0, uint112 reserve1) internal pure returns (uint256) {
        return Math.sqrt(uint256(reserve0) * uint256(reserve1));
    }
}
