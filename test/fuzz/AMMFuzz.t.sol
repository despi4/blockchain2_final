// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {IronToken} from "../../src/token/IronToken.sol";
import {ResourceAMM} from "../../src/amm/ResourceAMM.sol";

contract AMMFuzzTest is Test {
    GoldToken internal gold;
    IronToken internal iron;
    ResourceAMM internal amm;

    address internal user = address(0xA11CE);

    function setUp() public {
        gold = new GoldToken(address(this), address(this), 2_000_000 ether);
        iron = new IronToken(address(this), address(this), 2_000_000 ether);
        amm = new ResourceAMM(gold, iron);

        gold.approve(address(amm), type(uint256).max);
        iron.approve(address(amm), type(uint256).max);
        amm.addLiquidity(500_000 ether, 500_000 ether, address(this));

        gold.mint(user, 100_000 ether);
        iron.mint(user, 100_000 ether);
        vm.startPrank(user);
        gold.approve(address(amm), type(uint256).max);
        iron.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    function testFuzz_SwapToken0ForToken1(uint256 amountIn) public {
        amountIn = bound(amountIn, 1 ether, 10_000 ether);
        (uint112 reserve0Before, uint112 reserve1Before) = amm.getReserves();
        uint256 expectedOut = amm.getAmountOut(amountIn, reserve0Before, reserve1Before);
        vm.assume(expectedOut > 0);

        vm.prank(user);
        uint256 amountOut = amm.swapExactToken0ForToken1(amountIn, expectedOut, user);

        assertEq(amountOut, expectedOut);
        assertGt(iron.balanceOf(user), 100_000 ether);
    }

    function testFuzz_SwapToken1ForToken0(uint256 amountIn) public {
        amountIn = bound(amountIn, 1 ether, 10_000 ether);
        (uint112 reserve0Before, uint112 reserve1Before) = amm.getReserves();
        uint256 expectedOut = amm.getAmountOut(amountIn, reserve1Before, reserve0Before);
        vm.assume(expectedOut > 0);

        vm.prank(user);
        uint256 amountOut = amm.swapExactToken1ForToken0(amountIn, expectedOut, user);

        assertEq(amountOut, expectedOut);
        assertGt(gold.balanceOf(user), 100_000 ether);
    }

    function testFuzz_AddLiquidity(uint256 amount0, uint256 amount1) public {
        amount0 = bound(amount0, 1 ether, 5_000 ether);
        amount1 = bound(amount1, 1 ether, 5_000 ether);

        vm.prank(user);
        uint256 liquidity = amm.addLiquidity(amount0, amount1, user);

        assertGt(liquidity, 0);
        assertGt(amm.lpToken().balanceOf(user), 0);
    }

    function testFuzz_RemoveLiquidity(uint256 liquidity) public {
        uint256 lpBalance = amm.lpToken().balanceOf(address(this));
        liquidity = bound(liquidity, 1, lpBalance);

        uint256 goldBefore = gold.balanceOf(address(this));
        uint256 ironBefore = iron.balanceOf(address(this));

        (uint256 amount0, uint256 amount1) = amm.removeLiquidity(liquidity, address(this));

        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertEq(gold.balanceOf(address(this)), goldBefore + amount0);
        assertEq(iron.balanceOf(address(this)), ironBefore + amount1);
    }
}
