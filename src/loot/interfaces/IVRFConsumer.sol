// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IVRFConsumer {
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external;
}
