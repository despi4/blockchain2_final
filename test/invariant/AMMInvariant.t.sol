// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {IronToken} from "../../src/token/IronToken.sol";
import {ResourceAMM} from "../../src/amm/ResourceAMM.sol";

contract AMMHandler is Test {
    GoldToken public gold;
    IronToken public iron;
    ResourceAMM public amm;

    constructor(GoldToken gold_, IronToken iron_, ResourceAMM amm_) {
        gold = gold_;
        iron = iron_;
        amm = amm_;
        gold.approve(address(amm), type(uint256).max);
        iron.approve(address(amm), type(uint256).max);
    }

    function swap0For1(uint256 amountIn) external {
        amountIn = bound(amountIn, 1, 1_000 ether);
        gold.mint(address(this), amountIn);
        try amm.swapExactToken0ForToken1(amountIn, 1, address(this)) {} catch {}
    }

    function swap1For0(uint256 amountIn) external {
        amountIn = bound(amountIn, 1, 1_000 ether);
        iron.mint(address(this), amountIn);
        try amm.swapExactToken1ForToken0(amountIn, 1, address(this)) {} catch {}
    }
}

contract AMMInvariantTest is Test {
    GoldToken internal gold;
    IronToken internal iron;
    ResourceAMM internal amm;
    AMMHandler internal handler;
    uint256 internal initialK;

    function setUp() public {
        gold = new GoldToken(address(this), address(this), 2_000_000 ether);
        iron = new IronToken(address(this), address(this), 2_000_000 ether);
        amm = new ResourceAMM(gold, iron);
        gold.approve(address(amm), type(uint256).max);
        iron.approve(address(amm), type(uint256).max);
        amm.addLiquidity(500_000 ether, 500_000 ether, address(this));
        (uint112 r0, uint112 r1) = amm.getReserves();
        initialK = uint256(r0) * uint256(r1);

        handler = new AMMHandler(gold, iron, amm);
        gold.grantRole(gold.MINTER_ROLE(), address(handler));
        iron.grantRole(iron.MINTER_ROLE(), address(handler));
        targetContract(address(handler));
    }

    function invariant_KDoesNotDecreaseFromInitialLiquidity() public view {
        (uint112 r0, uint112 r1) = amm.getReserves();
        assertGe(uint256(r0) * uint256(r1), initialK);
    }
}
