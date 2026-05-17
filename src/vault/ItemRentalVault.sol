// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ItemRentalVault
/// @notice Custodial ERC1155 rental vault where users list game items and renters pay GOLD for time-limited rentals.
/// @dev The vault keeps custody of listed and rented items, preventing the same item from being withdrawn while rented.
contract ItemRentalVault is Ownable, ReentrancyGuard, ERC1155Holder {
    using SafeERC20 for IERC20;

    enum ListingStatus {
        NONE,
        LISTED,
        RENTED,
        RETURNED,
        CANCELLED
    }

    enum RentalStatus {
        NONE,
        ACTIVE,
        ENDED
    }

    struct Listing {
        address lender;
        uint256 itemId;
        uint256 amount;
        uint256 pricePerDay;
        uint64 maxDuration;
        ListingStatus status;
        uint256 activeRentalId;
    }

    struct Rental {
        uint256 listingId;
        address renter;
        uint64 startTime;
        uint64 endTime;
        uint256 totalPayment;
        uint256 protocolFee;
        RentalStatus status;
    }

    error ZeroAmount();
    error InvalidDuration();
    error InactiveListing(uint256 listingId);
    error ListingAlreadyRented(uint256 listingId);
    error RentalNotEnded(uint256 rentalId);
    error RentalAlreadyEnded(uint256 rentalId);
    error NotLender(uint256 listingId);
    error NoEarnings();
    error InvalidFeeBps();

    IERC1155 public immutable gameItems;
    IERC20 public immutable goldToken;

    uint256 public nextListingId;
    uint256 public nextRentalId;
    uint256 public protocolFeeBps;
    uint256 public totalProtocolFeesCollected;
    address public treasury;

    mapping(uint256 listingId => Listing listing) public listings;
    mapping(uint256 rentalId => Rental rental) public rentals;
    mapping(address lender => uint256 earnings) public claimableEarnings;

    event ItemListed(
        uint256 indexed listingId,
        address indexed lender,
        uint256 indexed itemId,
        uint256 amount,
        uint256 pricePerDay,
        uint64 maxDuration
    );
    event ItemRented(
        uint256 indexed rentalId,
        uint256 indexed listingId,
        address indexed renter,
        uint64 duration,
        uint256 totalPayment,
        uint256 protocolFee
    );
    event RentalEnded(uint256 indexed rentalId, uint256 indexed listingId, address indexed lender);
    event ListingCancelled(uint256 indexed listingId, address indexed lender);
    event EarningsClaimed(address indexed lender, uint256 amount);
    event ProtocolFeeUpdated(uint256 feeBps);
    event TreasuryUpdated(address indexed treasury);

    constructor(IERC1155 gameItems_, IERC20 goldToken_, address initialOwner, address treasury_, uint256 protocolFeeBps_)
        Ownable(initialOwner)
    {
        gameItems = gameItems_;
        goldToken = goldToken_;
        _setTreasury(treasury_);
        _setProtocolFeeBps(protocolFeeBps_);
    }

    function listItemForRent(uint256 itemId, uint256 amount, uint256 pricePerDay, uint64 maxDuration)
        external
        nonReentrant
        returns (uint256 listingId)
    {
        if (amount == 0 || pricePerDay == 0) revert ZeroAmount();
        if (maxDuration == 0) revert InvalidDuration();

        listingId = ++nextListingId;
        listings[listingId] = Listing({
            lender: msg.sender,
            itemId: itemId,
            amount: amount,
            pricePerDay: pricePerDay,
            maxDuration: maxDuration,
            status: ListingStatus.LISTED,
            activeRentalId: 0
        });

        gameItems.safeTransferFrom(msg.sender, address(this), itemId, amount, "");

        emit ItemListed(listingId, msg.sender, itemId, amount, pricePerDay, maxDuration);
    }

    function rentItem(uint256 listingId, uint64 duration) external nonReentrant returns (uint256 rentalId) {
        if (duration == 0) revert InvalidDuration();

        Listing storage listing = listings[listingId];
        if (listing.status != ListingStatus.LISTED) revert InactiveListing(listingId);
        if (listing.activeRentalId != 0) revert ListingAlreadyRented(listingId);
        if (duration > listing.maxDuration) revert InvalidDuration();

        uint256 totalPayment = listing.pricePerDay * duration;
        uint256 protocolFee = totalPayment * protocolFeeBps / 10_000;
        uint256 lenderProceeds = totalPayment - protocolFee;

        rentalId = ++nextRentalId;
        rentals[rentalId] = Rental({
            listingId: listingId,
            renter: msg.sender,
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp + uint256(duration) * 1 days),
            totalPayment: totalPayment,
            protocolFee: protocolFee,
            status: RentalStatus.ACTIVE
        });

        listing.status = ListingStatus.RENTED;
        listing.activeRentalId = rentalId;
        claimableEarnings[listing.lender] += lenderProceeds;
        totalProtocolFeesCollected += protocolFee;

        goldToken.safeTransferFrom(msg.sender, address(this), totalPayment);
        if (protocolFee != 0) {
            goldToken.safeTransfer(treasury, protocolFee);
        }

        emit ItemRented(rentalId, listingId, msg.sender, duration, totalPayment, protocolFee);
    }

    function endRental(uint256 rentalId) external nonReentrant {
        Rental storage rental = rentals[rentalId];
        if (rental.status != RentalStatus.ACTIVE) revert RentalAlreadyEnded(rentalId);
        if (block.timestamp < rental.endTime) revert RentalNotEnded(rentalId);

        Listing storage listing = listings[rental.listingId];

        rental.status = RentalStatus.ENDED;
        listing.status = ListingStatus.RETURNED;
        listing.activeRentalId = 0;

        gameItems.safeTransferFrom(address(this), listing.lender, listing.itemId, listing.amount, "");

        emit RentalEnded(rentalId, rental.listingId, listing.lender);
    }

    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        if (listing.lender != msg.sender) revert NotLender(listingId);
        if (listing.status != ListingStatus.LISTED) revert InactiveListing(listingId);

        listing.status = ListingStatus.CANCELLED;
        listing.activeRentalId = 0;

        gameItems.safeTransferFrom(address(this), listing.lender, listing.itemId, listing.amount, "");

        emit ListingCancelled(listingId, listing.lender);
    }

    function claimEarnings() external nonReentrant {
        uint256 amount = claimableEarnings[msg.sender];
        if (amount == 0) revert NoEarnings();

        claimableEarnings[msg.sender] = 0;
        goldToken.safeTransfer(msg.sender, amount);

        emit EarningsClaimed(msg.sender, amount);
    }

    function setProtocolFeeBps(uint256 feeBps) external onlyOwner {
        _setProtocolFeeBps(feeBps);
    }

    function setTreasury(address treasury_) external onlyOwner {
        _setTreasury(treasury_);
    }

    function _setProtocolFeeBps(uint256 feeBps) internal {
        if (feeBps > 10_000) revert InvalidFeeBps();
        protocolFeeBps = feeBps;
        emit ProtocolFeeUpdated(feeBps);
    }

    function _setTreasury(address treasury_) internal {
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }
}
