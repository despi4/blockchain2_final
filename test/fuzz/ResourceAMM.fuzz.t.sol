// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {IronToken} from "../../src/token/IronToken.sol";
import {ResourceAMM} from "../../src/amm/ResourceAMM.sol";
import {ResourceLPToken} from "../../src/amm/ResourceLPToken.sol";

contract ResourceAMMFuzzTest is Test {
    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    GoldToken internal gold;
    IronToken internal iron;
    ResourceAMM internal amm;
    ResourceLPToken internal lpToken;

    function setUp() external {
        gold = new GoldToken(admin, admin, 100_000_000 ether);
        iron = new IronToken(admin, admin, 100_000_000 ether);
        amm = new ResourceAMM(gold, iron);
        lpToken = amm.lpToken();

        vm.startPrank(admin);
        gold.mint(alice, 10_000_000 ether);
        iron.mint(alice, 10_000_000 ether);
        gold.mint(bob, 10_000_000 ether);
        iron.mint(bob, 10_000_000 ether);
        vm.stopPrank();

        vm.prank(alice);
        gold.approve(address(amm), type(uint256).max);
        vm.prank(alice);
        iron.approve(address(amm), type(uint256).max);
        vm.prank(bob);
        gold.approve(address(amm), type(uint256).max);
        vm.prank(bob);
        iron.approve(address(amm), type(uint256).max);

        vm.prank(alice);
        amm.addLiquidity(1_000_000 ether, 1_000_000 ether, alice);
    }

    function testFuzzSwapAmount(uint256 amountIn) external {
        amountIn = bound(amountIn, 1 ether, 100_000 ether);

        (uint112 reserve0Before, uint112 reserve1Before) = amm.getReserves();
        uint256 kBefore = uint256(reserve0Before) * uint256(reserve1Before);

        vm.prank(bob);
        uint256 amountOut = amm.swapExactToken0ForToken1(amountIn, 1, bob);

        assertGt(amountOut, 0);

        (uint112 reserve0After, uint112 reserve1After) = amm.getReserves();
        uint256 kAfter = uint256(reserve0After) * uint256(reserve1After);
        assertGe(kAfter, kBefore);
    }

    function testFuzzAddRemoveLiquidity(uint256 amount0, uint256 amount1) external {
        amount0 = bound(amount0, 1 ether, 100_000 ether);
        amount1 = bound(amount1, 1 ether, 100_000 ether);

        vm.prank(bob);
        uint256 liquidity = amm.addLiquidity(amount0, amount1, bob);
        assertGt(liquidity, 0);

        uint256 lpBefore = lpToken.balanceOf(bob);
        vm.prank(bob);
        amm.removeLiquidity(liquidity, bob);

        assertEq(lpToken.balanceOf(bob), lpBefore - liquidity);
    }

    function testFuzzKInvariant(uint256 amountIn) external {
        amountIn = bound(amountIn, 1 ether, 250_000 ether);

        (uint112 reserve0Before, uint112 reserve1Before) = amm.getReserves();
        uint256 kBefore = uint256(reserve0Before) * uint256(reserve1Before);

        vm.prank(bob);
        amm.swapExactToken1ForToken0(amountIn, 1, bob);

        (uint112 reserve0After, uint112 reserve1After) = amm.getReserves();
        uint256 kAfter = uint256(reserve0After) * uint256(reserve1After);
        assertGe(kAfter, kBefore);
    }
}
