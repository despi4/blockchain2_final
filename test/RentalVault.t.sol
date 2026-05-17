// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {RentalVault} from "../src/vault/RentalVault.sol";

contract MockERC721 is ERC721 {
    uint256 internal _nextId;

    constructor() ERC721("Mock NFT", "MNFT") {}

    function mint(address to) external returns (uint256 tokenId) {
        tokenId = ++_nextId;
        _mint(to, tokenId);
    }
}

contract RentalVaultTest is Test {
    RentalVault internal vault;
    MockERC721 internal nft;

    address internal lender = address(0xA11CE);
    address internal renter = address(0xB0B);

    function setUp() external {
        vault = new RentalVault(address(this));
        nft = new MockERC721();
    }

    function testReturnRentalKeepsAssetCustodiedForReuse() external {
        vm.startPrank(lender);
        uint256 tokenId = nft.mint(lender);
        nft.approve(address(vault), tokenId);
        uint256 listingId = vault.createListing(address(nft), tokenId, 1, false, 1 days, 1 ether, 2 ether);
        vm.stopPrank();

        vm.deal(renter, 3 ether);
        vm.prank(renter);
        vault.rent{value: 3 ether}(listingId);

        vm.startPrank(renter);
        nft.approve(address(vault), tokenId);
        vault.returnRental(1);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), address(vault));
        (,,,,,,,, bool active) = vault.listings(listingId);
        assertTrue(active);
        assertEq(vault.activeRentalByListing(listingId), 0);
    }

    function testClaimExpiredDisablesListing() external {
        vm.startPrank(lender);
        uint256 tokenId = nft.mint(lender);
        nft.approve(address(vault), tokenId);
        uint256 listingId = vault.createListing(address(nft), tokenId, 1, false, 1 days, 1 ether, 2 ether);
        vm.stopPrank();

        vm.deal(renter, 3 ether);
        vm.prank(renter);
        vault.rent{value: 3 ether}(listingId);

        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(lender);
        vault.claimExpired(1);

        (,,,,,,,, bool active) = vault.listings(listingId);
        assertFalse(active);
        assertEq(vault.activeRentalByListing(listingId), 0);
    }
}
