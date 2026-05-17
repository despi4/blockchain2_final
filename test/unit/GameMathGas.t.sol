// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameMath} from "../../src/math/GameMath.sol";
import {GameMathYul} from "../../src/math/GameMathYul.sol";

contract GameMathGasTest is Test {
    GameMath internal gameMath;
    GameMathYul internal gameMathYul;

    function setUp() external {
        gameMath = new GameMath();
        gameMathYul = new GameMathYul();
    }

    function testCalculateFeeFixedValuesMatch() external view {
        assertEq(gameMath.calculateFeeSolidity(1 ether, 30), gameMathYul.calculateFeeYul(1 ether, 30));
        assertEq(gameMath.calculateFeeSolidity(5000, 250), gameMathYul.calculateFeeYul(5000, 250));
        assertEq(gameMath.calculateFeeSolidity(123_456_789, 9999), gameMathYul.calculateFeeYul(123_456_789, 9999));
    }

    function testZeroAmount() external view {
        assertEq(gameMath.calculateFeeSolidity(0, 500), 0);
        assertEq(gameMathYul.calculateFeeYul(0, 500), 0);
    }

    function testZeroFee() external view {
        assertEq(gameMath.calculateFeeSolidity(100 ether, 0), 0);
        assertEq(gameMathYul.calculateFeeYul(100 ether, 0), 0);
    }

    function testMaxReasonableFee() external view {
        uint256 amount = 777 ether;
        uint256 feeBps = 10_000;

        assertEq(gameMath.calculateFeeSolidity(amount, feeBps), amount);
        assertEq(gameMathYul.calculateFeeYul(amount, feeBps), amount);
    }

    function testMinHelpers() external view {
        assertEq(gameMath.min(1, 2), 1);
        assertEq(gameMathYul.minYul(1, 2), 1);
        assertEq(gameMath.min(9, 4), 4);
        assertEq(gameMathYul.minYul(9, 4), 4);
    }

    function testSqrtHelper() external view {
        assertEq(gameMath.sqrt(0), 0);
        assertEq(gameMath.sqrt(1), 1);
        assertEq(gameMath.sqrt(16), 4);
        assertEq(gameMath.sqrt(20), 4);
    }

    function testOverflowBehaviorMatches() external {
        uint256 amount = type(uint256).max;
        uint256 feeBps = 2;

        vm.expectRevert();
        gameMath.calculateFeeSolidity(amount, feeBps);

        vm.expectRevert(GameMathYul.MultiplicationOverflow.selector);
        gameMathYul.calculateFeeYul(amount, feeBps);
    }

    function testFuzzCalculateFeeMatches(uint256 amount, uint256 feeBps) external view {
        vm.assume(feeBps == 0 || amount <= type(uint256).max / feeBps);

        uint256 solidityFee = gameMath.calculateFeeSolidity(amount, feeBps);
        uint256 yulFee = gameMathYul.calculateFeeYul(amount, feeBps);

        assertEq(yulFee, solidityFee);
    }

    function testFuzzMinMatches(uint256 a, uint256 b) external view {
        assertEq(gameMath.min(a, b), gameMathYul.minYul(a, b));
    }

    function testGasComparisonCalculateFee() external {
        uint256 amount = 1_000_000 ether;
        uint256 feeBps = 375;

        uint256 gasBeforeSolidity = gasleft();
        uint256 solidityFee = gameMath.calculateFeeSolidity(amount, feeBps);
        uint256 gasUsedSolidity = gasBeforeSolidity - gasleft();

        uint256 gasBeforeYul = gasleft();
        uint256 yulFee = gameMathYul.calculateFeeYul(amount, feeBps);
        uint256 gasUsedYul = gasBeforeYul - gasleft();

        assertEq(solidityFee, yulFee);

        emit log_named_uint("gas_calculateFeeSolidity", gasUsedSolidity);
        emit log_named_uint("gas_calculateFeeYul", gasUsedYul);
    }
}
