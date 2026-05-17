// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IProtocolConfig} from "../interfaces/IProtocolConfig.sol";
import {IResourcePool} from "../interfaces/IResourcePool.sol";
import {Errors} from "../libraries/Errors.sol";
import {ResourceMath} from "../math/ResourceMath.sol";

contract ResourcePool is ERC20, ReentrancyGuard, IResourcePool {
    using SafeERC20 for IERC20;

    address public immutable token0;
    address public immutable token1;
    IProtocolConfig public immutable protocolConfig;

    uint112 private _reserve0;
    uint112 private _reserve1;

    event Swap(address indexed sender, address indexed tokenIn, uint256 amountIn, uint256 amountOut, address indexed to);
    event LiquidityAdded(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity, address indexed to);
    event LiquidityRemoved(address indexed sender, uint256 liquidity, uint256 amount0, uint256 amount1, address indexed to);

    constructor(address token0_, address token1_, IProtocolConfig protocolConfig_) ERC20("Resource LP", "RLP") {
        if (token0_ == token1_ || token0_ == address(0) || token1_ == address(0)) revert Errors.InvalidAsset();
        (token0, token1) = token0_ < token1_ ? (token0_, token1_) : (token1_, token0_);
        protocolConfig = protocolConfig_;
    }

    function addLiquidity(uint256 amount0, uint256 amount1, address to)
        external
        override
        nonReentrant
        returns (uint256 liquidity)
    {
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        if (totalSupply() == 0) {
            liquidity = ResourceMath.totalLiquidity(uint112(amount0), uint112(amount1));
        } else {
            uint256 liquidity0 = amount0 * totalSupply() / _reserve0;
            uint256 liquidity1 = amount1 * totalSupply() / _reserve1;
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }
        if (liquidity == 0) revert Errors.InsufficientLiquidity();

        _mint(to, liquidity);
        _sync();
        emit LiquidityAdded(msg.sender, amount0, amount1, liquidity, to);
    }

    function removeLiquidity(uint256 liquidity, address to)
        external
        override
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 supply = totalSupply();
        amount0 = liquidity * _reserve0 / supply;
        amount1 = liquidity * _reserve1 / supply;
        if (amount0 == 0 || amount1 == 0) revert Errors.InsufficientLiquidity();

        _burn(msg.sender, liquidity);
        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);
        _sync();

        emit LiquidityRemoved(msg.sender, liquidity, amount0, amount1, to);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address to)
        external
        override
        nonReentrant
        returns (uint256 amountOut)
    {
        if (tokenIn != token0 && tokenIn != token1) revert Errors.InvalidAsset();
        bool zeroForOne = tokenIn == token0;

        (uint112 reserveIn, uint112 reserveOut) = zeroForOne ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        uint256 feeBps = protocolConfig.marketplaceFeeBps();
        amountOut = ResourceMath.getAmountOut(amountIn, reserveIn, reserveOut, feeBps);
        if (amountOut < minAmountOut) revert Errors.SlippageExceeded();

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(zeroForOne ? token1 : token0).safeTransfer(to, amountOut);
        _sync();

        emit Swap(msg.sender, tokenIn, amountIn, amountOut, to);
    }

    function getReserves() external view override returns (uint112 reserve0, uint112 reserve1) {
        return (_reserve0, _reserve1);
    }

    function quoteSwap(address tokenIn, uint256 amountIn) external view override returns (uint256 amountOut) {
        if (tokenIn != token0 && tokenIn != token1) revert Errors.InvalidAsset();
        bool zeroForOne = tokenIn == token0;
        (uint112 reserveIn, uint112 reserveOut) = zeroForOne ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        return ResourceMath.getAmountOut(amountIn, reserveIn, reserveOut, protocolConfig.marketplaceFeeBps());
    }

    function _sync() internal {
        _reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
        _reserve1 = uint112(IERC20(token1).balanceOf(address(this)));
    }
}
