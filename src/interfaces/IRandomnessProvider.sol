// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRandomnessProvider {
    function requestRandomWords(bytes32 keyHash, uint32 callbackGasLimit, uint16 confirmations, uint32 numWords)
        external
        returns (uint256 requestId);
}
