// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {TransferLib} from "../libraries/TransferLib.sol";
import {IRentalVault} from "../interfaces/IRentalVault.sol";

contract RentalVault is Ownable, ReentrancyGuard, ERC1155Holder, ERC721Holder, IRentalVault {
    uint256 public nextListingId;
    uint256 public nextRentalId;

    mapping(uint256 listingId => DataTypes.RentalListing listing) public listings;
    mapping(uint256 rentalId => DataTypes.ActiveRental rental) public rentals;
    mapping(uint256 listingId => uint256 rentalId) public activeRentalByListing;

    event ListingCreated(uint256 indexed listingId, address indexed lender, address indexed asset);
    event ListingCancelled(uint256 indexed listingId);
    event RentalStarted(uint256 indexed rentalId, uint256 indexed listingId, address indexed renter, uint64 endTime);
    event RentalReturned(uint256 indexed rentalId);
    event RentalExpiredClaimed(uint256 indexed rentalId);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function createListing(
        address asset,
        uint256 id,
        uint256 amount,
        bool is1155,
        uint64 duration,
        uint256 price,
        uint256 collateral
    ) external override nonReentrant returns (uint256 listingId) {
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (duration == 0 || amount == 0) revert Errors.InvalidConfiguration();

        listingId = ++nextListingId;
        listings[listingId] = DataTypes.RentalListing({
            lender: msg.sender,
            asset: asset,
            tokenId: id,
            amount: amount,
            is1155: is1155,
            duration: duration,
            price: price,
            collateral: collateral,
            active: true
        });

        if (is1155) {
            IERC1155(asset).safeTransferFrom(msg.sender, address(this), id, amount, "");
        } else {
            if (amount != 1) revert Errors.InvalidConfiguration();
            IERC721(asset).transferFrom(msg.sender, address(this), id);
        }

        emit ListingCreated(listingId, msg.sender, asset);
    }

    function rent(uint256 listingId) external payable override nonReentrant {
        DataTypes.RentalListing storage listing = listings[listingId];
        if (!listing.active) revert Errors.InvalidListing();
        if (activeRentalByListing[listingId] != 0) revert Errors.InvalidRental();
        if (msg.value != listing.price + listing.collateral) revert Errors.InvalidConfiguration();

        uint256 rentalId = ++nextRentalId;
        uint64 endTime = uint64(block.timestamp + listing.duration);
        rentals[rentalId] = DataTypes.ActiveRental({
            listingId: listingId,
            renter: msg.sender,
            startTime: uint64(block.timestamp),
            endTime: endTime,
            settled: false
        });
        activeRentalByListing[listingId] = rentalId;

        if (listing.is1155) {
            IERC1155(listing.asset).safeTransferFrom(address(this), msg.sender, listing.tokenId, listing.amount, "");
        } else {
            IERC721(listing.asset).safeTransferFrom(address(this), msg.sender, listing.tokenId);
        }

        emit RentalStarted(rentalId, listingId, msg.sender, endTime);
    }

    function returnRental(uint256 rentalId) external override nonReentrant {
        DataTypes.ActiveRental storage rental = rentals[rentalId];
        if (rental.settled) revert Errors.AlreadyProcessed();
        if (rental.renter != msg.sender) revert Errors.Unauthorized();

        DataTypes.RentalListing storage listing = listings[rental.listingId];
        rental.settled = true;
        activeRentalByListing[rental.listingId] = 0;

        if (listing.is1155) {
            IERC1155(listing.asset).safeTransferFrom(msg.sender, address(this), listing.tokenId, listing.amount, "");
        } else {
            IERC721(listing.asset).safeTransferFrom(msg.sender, address(this), listing.tokenId);
        }

        TransferLib.safeTransferNative(listing.lender, listing.price);
        TransferLib.safeTransferNative(msg.sender, listing.collateral);

        emit RentalReturned(rentalId);
    }

    function claimExpired(uint256 rentalId) external override nonReentrant {
        DataTypes.ActiveRental storage rental = rentals[rentalId];
        if (rental.settled) revert Errors.AlreadyProcessed();

        DataTypes.RentalListing storage listing = listings[rental.listingId];
        if (msg.sender != listing.lender) revert Errors.Unauthorized();
        if (block.timestamp < rental.endTime) revert Errors.NotExpired();

        rental.settled = true;
        listing.active = false;
        activeRentalByListing[rental.listingId] = 0;

        TransferLib.safeTransferNative(listing.lender, listing.price + listing.collateral);
        emit RentalExpiredClaimed(rentalId);
    }

    function cancelListing(uint256 listingId) external override nonReentrant {
        DataTypes.RentalListing storage listing = listings[listingId];
        if (!listing.active) revert Errors.InvalidListing();
        if (listing.lender != msg.sender) revert Errors.Unauthorized();
        if (activeRentalByListing[listingId] != 0) revert Errors.InvalidRental();

        listing.active = false;
        if (listing.is1155) {
            IERC1155(listing.asset).safeTransferFrom(address(this), msg.sender, listing.tokenId, listing.amount, "");
        } else {
            IERC721(listing.asset).safeTransferFrom(address(this), msg.sender, listing.tokenId);
        }

        emit ListingCancelled(listingId);
    }
}
