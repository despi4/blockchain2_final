// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ResourceLPToken} from "./ResourceLPToken.sol";

/// @title ResourceAMM
/// @notice Constant-product AMM for fungible GameFi resource tokens such as GOLD and IRON.
contract ResourceAMM is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_BPS = 30;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    ResourceLPToken public immutable lpToken;

    uint112 private _reserve0;
    uint112 private _reserve1;

    error InvalidToken();
    error ZeroAmount();
    error ZeroLiquidity();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();

    event LiquidityAdded(
        address indexed provider,
        address indexed to,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted
    );

    event LiquidityRemoved(
        address indexed provider,
        address indexed to,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityBurned
    );

    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
    );

    constructor(IERC20 token0_, IERC20 token1_) {
        if (address(token0_) == address(0) || address(token1_) == address(0) || address(token0_) == address(token1_)) {
            revert InvalidToken();
        }

        token0 = token0_;
        token1 = token1_;
        lpToken = new ResourceLPToken(
            address(this),
            string.concat("LP-", IERC20Metadata(address(token0_)).symbol(), "-", IERC20Metadata(address(token1_)).symbol()),
            string.concat("LP", IERC20Metadata(address(token0_)).symbol(), IERC20Metadata(address(token1_)).symbol())
        );
    }

    /// @notice Returns the stored reserves used for pricing.
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1) {
        return (_reserve0, _reserve1);
    }

    /// @notice Adds liquidity and mints LP shares.
    function addLiquidity(uint256 amount0, uint256 amount1, address to) external nonReentrant returns (uint256 liquidity) {
        if (amount0 == 0 || amount1 == 0) revert ZeroAmount();

        uint112 reserve0 = _reserve0;
        uint112 reserve1 = _reserve1;
        uint256 totalSupply = lpToken.totalSupply();

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1);
        } else {
            uint256 liquidity0 = Math.mulDiv(amount0, totalSupply, reserve0);
            uint256 liquidity1 = Math.mulDiv(amount1, totalSupply, reserve1);
            liquidity = Math.min(liquidity0, liquidity1);
        }

        if (liquidity == 0) revert ZeroLiquidity();

        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        lpToken.mint(to, liquidity);
        _syncReserves();

        emit LiquidityAdded(msg.sender, to, amount0, amount1, liquidity);
    }

    /// @notice Removes liquidity and burns LP shares.
    function removeLiquidity(uint256 liquidity, address to)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (liquidity == 0) revert ZeroAmount();

        uint256 totalSupply = lpToken.totalSupply();
        uint112 reserve0 = _reserve0;
        uint112 reserve1 = _reserve1;
        if (totalSupply == 0 || reserve0 == 0 || reserve1 == 0) revert InsufficientLiquidity();

        amount0 = Math.mulDiv(liquidity, reserve0, totalSupply);
        amount1 = Math.mulDiv(liquidity, reserve1, totalSupply);
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();

        lpToken.burn(msg.sender, liquidity);
        token0.safeTransfer(to, amount0);
        token1.safeTransfer(to, amount1);
        _syncReserves();

        emit LiquidityRemoved(msg.sender, to, amount0, amount1, liquidity);
    }

    /// @notice Quotes output amount after a 0.3% fee.
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * (BPS_DENOMINATOR - FEE_BPS);
        amountOut = Math.mulDiv(amountInWithFee, reserveOut, reserveIn * BPS_DENOMINATOR + amountInWithFee);
    }

    /// @notice Swaps exact token0 for token1.
    function swapExactToken0ForToken1(uint256 amountIn, uint256 minAmountOut, address to)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        amountOut = _swap(token0, token1, _reserve0, _reserve1, amountIn, minAmountOut, to);
    }

    /// @notice Swaps exact token1 for token0.
    function swapExactToken1ForToken0(uint256 amountIn, uint256 minAmountOut, address to)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        amountOut = _swap(token1, token0, _reserve1, _reserve0, amountIn, minAmountOut, to);
    }

    function _swap(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint112 reserveIn,
        uint112 reserveOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) internal returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut < minAmountOut || amountOut == 0) revert InsufficientOutputAmount();

        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        tokenOut.safeTransfer(to, amountOut);
        _syncReserves();

        emit Swap(msg.sender, address(tokenIn), address(tokenOut), amountIn, amountOut, to);
    }

    function _syncReserves() internal {
        _reserve0 = uint112(token0.balanceOf(address(this)));
        _reserve1 = uint112(token1.balanceOf(address(this)));
    }
}
