// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract AssemblyBenchmark {
    function sumWeightsSolidity(uint96[] memory weights) public pure returns (uint256 total) {
        for (uint256 i = 0; i < weights.length; ++i) {
            total += weights[i];
        }
    }

    function sumWeightsYul(uint96[] memory weights) public pure returns (uint256 total) {
        assembly {
            let length := mload(weights)
            let ptr := add(weights, 0x20)
            let end := add(ptr, mul(length, 0x20))
            for { } lt(ptr, end) { ptr := add(ptr, 0x20) } {
                total := add(total, mload(ptr))
            }
        }
    }
}
