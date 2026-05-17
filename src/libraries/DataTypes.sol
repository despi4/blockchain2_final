// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library DataTypes {
    enum ItemCategory {
        Undefined,
        Resource,
        Consumable,
        Equipment,
        LootBox,
        Trophy
    }

    struct ItemConfig {
        ItemCategory category;
        bool craftable;
        bool lootable;
        bool rentable;
        string metadataURI;
    }

    struct RecipeInput {
        address asset;
        uint256 id;
        uint256 amount;
        bool isERC1155;
    }

    struct RecipeOutput {
        uint256 itemId;
        uint256 amount;
    }

    struct LootEntry {
        uint256 itemId;
        uint256 amount;
        uint96 weight;
    }

    struct LootTableConfig {
        bool enabled;
        uint32 minRolls;
        uint32 maxRolls;
    }

    struct RentalListing {
        address lender;
        address asset;
        uint256 tokenId;
        uint256 amount;
        bool is1155;
        uint64 duration;
        uint256 price;
        uint256 collateral;
        bool active;
    }

    struct ActiveRental {
        uint256 listingId;
        address renter;
        uint64 startTime;
        uint64 endTime;
        bool settled;
    }

    struct OracleFeedConfig {
        address feed;
        uint48 heartbeat;
        uint8 decimals;
        bool enabled;
    }
}
