// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGameItems1155} from "../interfaces/IGameItems1155.sol";
import {IRandomnessProvider} from "../interfaces/IRandomnessProvider.sol";

/// @title LootDrop
/// @notice Chainlink-VRF-style loot drop contract that requests randomness and mints ERC1155 rewards on fulfillment.
contract LootDrop is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant TOTAL_BPS = 10_000;

    error InvalidDropRates();
    error InvalidRequest(uint256 requestId);
    error AlreadyFulfilled(uint256 requestId);
    error UnauthorizedCoordinator(address caller);
    error InvalidTreasury();

    struct PendingRequest {
        address user;
        bool fulfilled;
    }

    IGameItems1155 public immutable gameItems;
    IERC20 public immutable goldToken;
    IRandomnessProvider public coordinator;

    bytes32 public keyHash;
    uint32 public callbackGasLimit;
    uint16 public requestConfirmations;
    uint32 public numWords;

    uint256 public lootFee;
    address public treasury;

    uint256[] private _dropItemIds;
    uint16[] private _dropRatesBps;

    mapping(uint256 requestId => PendingRequest request) public pendingRequests;

    event LootRequested(uint256 indexed requestId, address indexed user, uint256 feePaid);
    event LootFulfilled(uint256 indexed requestId, address indexed user, uint256 indexed itemId, uint256 randomness);
    event DropRatesUpdated(uint256[] itemIds, uint16[] dropRatesBps);
    event LootFeeUpdated(uint256 oldFee, uint256 newFee);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event CoordinatorUpdated(address indexed oldCoordinator, address indexed newCoordinator);

    constructor(
        address initialOwner,
        IGameItems1155 gameItems_,
        IERC20 goldToken_,
        IRandomnessProvider coordinator_,
        address treasury_
    ) Ownable(initialOwner) {
        gameItems = gameItems_;
        goldToken = goldToken_;
        coordinator = coordinator_;
        keyHash = bytes32(0);
        callbackGasLimit = 300_000;
        requestConfirmations = 3;
        numWords = 1;
        _setTreasury(treasury_);
    }

    /// @notice Requests a randomness-backed loot drop for the caller.
    function requestLootDrop() external nonReentrant returns (uint256 requestId) {
        if (lootFee != 0) {
            goldToken.safeTransferFrom(msg.sender, treasury, lootFee);
        }

        requestId = coordinator.requestRandomWords(keyHash, callbackGasLimit, requestConfirmations, numWords);
        pendingRequests[requestId] = PendingRequest({user: msg.sender, fulfilled: false});

        emit LootRequested(requestId, msg.sender, lootFee);
    }

    /// @notice Fulfillment entrypoint called by the configured coordinator/mock.
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external nonReentrant {
        if (msg.sender != address(coordinator)) revert UnauthorizedCoordinator(msg.sender);
        if (randomWords.length == 0) revert InvalidRequest(requestId);

        PendingRequest storage request = pendingRequests[requestId];
        if (request.user == address(0)) revert InvalidRequest(requestId);
        if (request.fulfilled) revert AlreadyFulfilled(requestId);

        request.fulfilled = true;
        uint256 itemId = _selectItem(randomWords[0]);
        gameItems.mint(request.user, itemId, 1, "");

        emit LootFulfilled(requestId, request.user, itemId, randomWords[0]);
    }

    /// @notice Updates loot drop item ids and rates.
    function setDropRates(uint256[] calldata itemIds, uint16[] calldata dropRatesBps) external onlyOwner {
        if (itemIds.length == 0 || itemIds.length != dropRatesBps.length) revert InvalidDropRates();

        uint256 total;
        for (uint256 i = 0; i < itemIds.length; ++i) {
            if (itemIds[i] == 0 || dropRatesBps[i] == 0) revert InvalidDropRates();
            total += dropRatesBps[i];
        }
        if (total != TOTAL_BPS) revert InvalidDropRates();

        _dropItemIds = itemIds;
        _dropRatesBps = dropRatesBps;

        emit DropRatesUpdated(itemIds, dropRatesBps);
    }

    /// @notice Updates the flat GOLD loot fee.
    function setLootFee(uint256 newLootFee) external onlyOwner {
        uint256 oldFee = lootFee;
        lootFee = newLootFee;
        emit LootFeeUpdated(oldFee, newLootFee);
    }

    /// @notice Updates the treasury address that receives loot fees.
    function setTreasury(address newTreasury) external onlyOwner {
        address oldTreasury = treasury;
        _setTreasury(newTreasury);
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /// @notice Updates the randomness coordinator address.
    function setCoordinator(IRandomnessProvider newCoordinator) external onlyOwner {
        address oldCoordinator = address(coordinator);
        coordinator = newCoordinator;
        emit CoordinatorUpdated(oldCoordinator, address(newCoordinator));
    }

    /// @notice Returns the configured item ids and drop rate basis points.
    function getDropRates() external view returns (uint256[] memory itemIds, uint16[] memory dropRatesBps) {
        return (_dropItemIds, _dropRatesBps);
    }

    function _selectItem(uint256 randomness) internal view returns (uint256 itemId) {
        if (_dropItemIds.length == 0) revert InvalidDropRates();

        uint256 roll = randomness % TOTAL_BPS;
        uint256 cumulative;

        for (uint256 i = 0; i < _dropRatesBps.length; ++i) {
            cumulative += _dropRatesBps[i];
            if (roll < cumulative) {
                return _dropItemIds[i];
            }
        }

        revert InvalidDropRates();
    }

    function _setTreasury(address newTreasury) internal {
        if (newTreasury == address(0)) revert InvalidTreasury();
        treasury = newTreasury;
    }
}
