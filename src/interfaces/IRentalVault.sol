// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRentalVault {
    function createListing(
        address asset,
        uint256 id,
        uint256 amount,
        bool is1155,
        uint64 duration,
        uint256 price,
        uint256 collateral
    ) external returns (uint256 listingId);

    function rent(uint256 listingId) external payable;
    function returnRental(uint256 rentalId) external;
    function claimExpired(uint256 rentalId) external;
    function cancelListing(uint256 listingId) external;
}
