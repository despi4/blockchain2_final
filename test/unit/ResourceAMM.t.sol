// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {IronToken} from "../../src/token/IronToken.sol";
import {ResourceAMM} from "../../src/amm/ResourceAMM.sol";
import {ResourceLPToken} from "../../src/amm/ResourceLPToken.sol";

contract ResourceAMMTest is Test {
    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    GoldToken internal gold;
    IronToken internal iron;
    ResourceAMM internal amm;
    ResourceLPToken internal lpToken;

    function setUp() external {
        gold = new GoldToken(admin, admin, 10_000_000 ether);
        iron = new IronToken(admin, admin, 10_000_000 ether);
        amm = new ResourceAMM(gold, iron);
        lpToken = amm.lpToken();

        vm.startPrank(admin);
        gold.mint(alice, 1_000_000 ether);
        iron.mint(alice, 1_000_000 ether);
        gold.mint(bob, 1_000_000 ether);
        iron.mint(bob, 1_000_000 ether);
        vm.stopPrank();

        vm.prank(alice);
        gold.approve(address(amm), type(uint256).max);
        vm.prank(alice);
        iron.approve(address(amm), type(uint256).max);
        vm.prank(bob);
        gold.approve(address(amm), type(uint256).max);
        vm.prank(bob);
        iron.approve(address(amm), type(uint256).max);
    }

    function _seedInitialLiquidity() internal returns (uint256 liquidity) {
        vm.prank(alice);
        liquidity = amm.addLiquidity(1_000 ether, 1_000 ether, alice);
    }

    function testAddInitialLiquidity() external {
        uint256 liquidity = _seedInitialLiquidity();
        (uint112 reserve0, uint112 reserve1) = amm.getReserves();

        assertEq(liquidity, 1_000 ether);
        assertEq(reserve0, 1_000 ether);
        assertEq(reserve1, 1_000 ether);
        assertEq(lpToken.balanceOf(alice), liquidity);
    }

    function testAddSecondLiquidityProportionally() external {
        _seedInitialLiquidity();

        vm.prank(bob);
        uint256 liquidity = amm.addLiquidity(500 ether, 500 ether, bob);

        (uint112 reserve0, uint112 reserve1) = amm.getReserves();
        assertEq(liquidity, 500 ether);
        assertEq(reserve0, 1_500 ether);
        assertEq(reserve1, 1_500 ether);
        assertEq(lpToken.balanceOf(bob), 500 ether);
    }

    function testRemoveLiquidity() external {
        uint256 liquidity = _seedInitialLiquidity();

        vm.prank(alice);
        (uint256 amount0, uint256 amount1) = amm.removeLiquidity(liquidity / 2, alice);

        assertEq(amount0, 500 ether);
        assertEq(amount1, 500 ether);
        assertEq(lpToken.balanceOf(alice), 500 ether);
    }

    function testSwapToken0ToToken1() external {
        _seedInitialLiquidity();

        uint256 ironBefore = iron.balanceOf(bob);
        vm.prank(bob);
        uint256 amountOut = amm.swapExactToken0ForToken1(100 ether, 1, bob);

        assertGt(amountOut, 0);
        assertEq(iron.balanceOf(bob) - ironBefore, amountOut);
    }

    function testSwapToken1ToToken0() external {
        _seedInitialLiquidity();

        uint256 goldBefore = gold.balanceOf(bob);
        vm.prank(bob);
        uint256 amountOut = amm.swapExactToken1ForToken0(100 ether, 1, bob);

        assertGt(amountOut, 0);
        assertEq(gold.balanceOf(bob) - goldBefore, amountOut);
    }

    function testFeeIsApplied() external {
        _seedInitialLiquidity();

        uint256 amountIn = 100 ether;
        uint256 reserveIn = 1_000 ether;
        uint256 reserveOut = 1_000 ether;
        uint256 quotedOut = amm.getAmountOut(amountIn, reserveIn, reserveOut);
        uint256 noFeeOut = (amountIn * reserveOut) / (reserveIn + amountIn);

        assertLt(quotedOut, noFeeOut);
    }

    function testSlippageProtectionReverts() external {
        _seedInitialLiquidity();

        vm.expectRevert(ResourceAMM.InsufficientOutputAmount.selector);
        vm.prank(bob);
        amm.swapExactToken0ForToken1(100 ether, 1_000 ether, bob);
    }

    function testZeroInputReverts() external {
        _seedInitialLiquidity();

        vm.expectRevert(ResourceAMM.ZeroAmount.selector);
        vm.prank(bob);
        amm.swapExactToken0ForToken1(0, 0, bob);
    }

    function testInsufficientLiquidityReverts() external {
        vm.expectRevert(ResourceAMM.InsufficientLiquidity.selector);
        vm.prank(bob);
        amm.swapExactToken0ForToken1(10 ether, 0, bob);
    }

    function testKInvariantShouldNotDecreaseAfterSwap() external {
        _seedInitialLiquidity();
        (uint112 reserve0Before, uint112 reserve1Before) = amm.getReserves();
        uint256 kBefore = uint256(reserve0Before) * uint256(reserve1Before);

        vm.prank(bob);
        amm.swapExactToken0ForToken1(100 ether, 1, bob);

        (uint112 reserve0After, uint112 reserve1After) = amm.getReserves();
        uint256 kAfter = uint256(reserve0After) * uint256(reserve1After);

        assertGe(kAfter, kBefore);
    }

    function testLPTokenBalancesUpdateCorrectly() external {
        uint256 aliceLiquidity = _seedInitialLiquidity();

        vm.prank(bob);
        uint256 bobLiquidity = amm.addLiquidity(250 ether, 250 ether, bob);

        assertEq(lpToken.balanceOf(alice), aliceLiquidity);
        assertEq(lpToken.balanceOf(bob), bobLiquidity);

        vm.prank(bob);
        amm.removeLiquidity(bobLiquidity / 2, bob);

        assertEq(lpToken.balanceOf(bob), bobLiquidity / 2);
    }
}
