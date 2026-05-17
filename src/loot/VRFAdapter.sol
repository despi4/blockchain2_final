// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRandomnessProvider} from "../interfaces/IRandomnessProvider.sol";
import {Errors} from "../libraries/Errors.sol";
import {IVRFConsumer} from "./interfaces/IVRFConsumer.sol";

contract VRFAdapter is Ownable {
    IRandomnessProvider public provider;
    bytes32 public keyHash;
    uint32 public callbackGasLimit;
    uint16 public requestConfirmations;
    uint32 public numWords;

    mapping(address consumer => bool allowed) public allowedConsumers;
    mapping(uint256 requestId => address consumer) public requestConsumers;

    event ConsumerUpdated(address indexed consumer, bool allowed);
    event ProviderUpdated(address indexed provider);
    event RandomnessRequested(uint256 indexed requestId, address indexed consumer);

    constructor(address initialOwner, IRandomnessProvider provider_) Ownable(initialOwner) {
        provider = provider_;
        callbackGasLimit = 300_000;
        requestConfirmations = 3;
        numWords = 1;
    }

    function setProvider(IRandomnessProvider provider_) external onlyOwner {
        provider = provider_;
        emit ProviderUpdated(address(provider_));
    }

    function setRequestConfig(bytes32 keyHash_, uint32 callbackGasLimit_, uint16 confirmations_, uint32 numWords_)
        external
        onlyOwner
    {
        keyHash = keyHash_;
        callbackGasLimit = callbackGasLimit_;
        requestConfirmations = confirmations_;
        numWords = numWords_;
    }

    function setConsumer(address consumer, bool allowed) external onlyOwner {
        allowedConsumers[consumer] = allowed;
        emit ConsumerUpdated(consumer, allowed);
    }

    function requestRandomness() external returns (uint256 requestId) {
        if (!allowedConsumers[msg.sender]) revert Errors.Unauthorized();
        requestId = provider.requestRandomWords(keyHash, callbackGasLimit, requestConfirmations, numWords);
        requestConsumers[requestId] = msg.sender;
        emit RandomnessRequested(requestId, msg.sender);
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        if (msg.sender != address(provider)) revert Errors.Unauthorized();
        address consumer = requestConsumers[requestId];
        if (consumer == address(0)) revert Errors.RequestNotFound();
        delete requestConsumers[requestId];
        IVRFConsumer(consumer).fulfillRandomWords(requestId, randomWords);
    }
}
