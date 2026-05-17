// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRandomnessProvider} from "../../interfaces/IRandomnessProvider.sol";
import {LootDrop} from "../LootDrop.sol";

/// @title MockLootVRFCoordinator
/// @notice Deterministic mock coordinator for Foundry tests.
contract MockLootVRFCoordinator is IRandomnessProvider {
    uint256 public nextRequestId;
    mapping(uint256 requestId => address requester) public requesters;

    function requestRandomWords(bytes32, uint32, uint16, uint32) external returns (uint256 requestId) {
        requestId = ++nextRequestId;
        requesters[requestId] = msg.sender;
    }

    function fulfillRequest(uint256 requestId, uint256 randomness) external {
        address requester = requesters[requestId];
        require(requester != address(0), "UNKNOWN_REQUEST");

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomness;
        LootDrop(requester).fulfillRandomWords(requestId, randomWords);
    }
}
