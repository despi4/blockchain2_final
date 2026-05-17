// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title GameConfigV1
/// @notice UUPS-upgradeable storage contract for DAO-governed GameFi parameters.
/// @dev Ownership can later be transferred to a timelock so governance controls all parameter updates and upgrades.
contract GameConfigV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public craftingFee;
    uint256 public marketplaceFeeBps;
    uint256 public rentalFeeBps;
    uint256 public lootFee;
    address public treasury;
    uint256 public maxStaleness;
    bool public craftingEnabled;
    bool public lootEnabled;

    event CraftingFeeUpdated(uint256 oldCraftingFee, uint256 newCraftingFee);
    event MarketplaceFeeBpsUpdated(uint256 oldMarketplaceFeeBps, uint256 newMarketplaceFeeBps);
    event RentalFeeBpsUpdated(uint256 oldRentalFeeBps, uint256 newRentalFeeBps);
    event LootFeeUpdated(uint256 oldLootFee, uint256 newLootFee);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event MaxStalenessUpdated(uint256 oldMaxStaleness, uint256 newMaxStaleness);
    event CraftingEnabledUpdated(bool oldCraftingEnabled, bool newCraftingEnabled);
    event LootEnabledUpdated(bool oldLootEnabled, bool newLootEnabled);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the upgradeable config proxy.
    function initialize(
        address initialOwner,
        address treasury_,
        uint256 craftingFee_,
        uint256 marketplaceFeeBps_,
        uint256 rentalFeeBps_,
        uint256 lootFee_,
        uint256 maxStaleness_,
        bool craftingEnabled_,
        bool lootEnabled_
    ) external initializer {
        __Ownable_init(initialOwner);

        _setTreasury(treasury_);
        craftingFee = craftingFee_;
        marketplaceFeeBps = marketplaceFeeBps_;
        rentalFeeBps = rentalFeeBps_;
        lootFee = lootFee_;
        maxStaleness = maxStaleness_;
        craftingEnabled = craftingEnabled_;
        lootEnabled = lootEnabled_;
    }

    /// @notice Updates the crafting fee.
    function setCraftingFee(uint256 newCraftingFee) external onlyOwner {
        emit CraftingFeeUpdated(craftingFee, newCraftingFee);
        craftingFee = newCraftingFee;
    }

    /// @notice Updates the marketplace fee in basis points.
    function setMarketplaceFeeBps(uint256 newMarketplaceFeeBps) external onlyOwner {
        emit MarketplaceFeeBpsUpdated(marketplaceFeeBps, newMarketplaceFeeBps);
        marketplaceFeeBps = newMarketplaceFeeBps;
    }

    /// @notice Updates the rental fee in basis points.
    function setRentalFeeBps(uint256 newRentalFeeBps) external onlyOwner {
        emit RentalFeeBpsUpdated(rentalFeeBps, newRentalFeeBps);
        rentalFeeBps = newRentalFeeBps;
    }

    /// @notice Updates the loot fee.
    function setLootFee(uint256 newLootFee) external onlyOwner {
        emit LootFeeUpdated(lootFee, newLootFee);
        lootFee = newLootFee;
    }

    /// @notice Updates the treasury address.
    function setTreasury(address newTreasury) external onlyOwner {
        address oldTreasury = treasury;
        _setTreasury(newTreasury);
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /// @notice Updates the oracle staleness threshold.
    function setMaxStaleness(uint256 newMaxStaleness) external onlyOwner {
        emit MaxStalenessUpdated(maxStaleness, newMaxStaleness);
        maxStaleness = newMaxStaleness;
    }

    /// @notice Enables or disables crafting.
    function setCraftingEnabled(bool newCraftingEnabled) external onlyOwner {
        emit CraftingEnabledUpdated(craftingEnabled, newCraftingEnabled);
        craftingEnabled = newCraftingEnabled;
    }

    /// @notice Enables or disables loot.
    function setLootEnabled(bool newLootEnabled) external onlyOwner {
        emit LootEnabledUpdated(lootEnabled, newLootEnabled);
        lootEnabled = newLootEnabled;
    }

    function _setTreasury(address newTreasury) internal {
        require(newTreasury != address(0), "INVALID_TREASURY");
        treasury = newTreasury;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
