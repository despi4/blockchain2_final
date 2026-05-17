// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {GuildTreasuryVaultV1} from "../../src/vault/GuildTreasuryVaultV1.sol";
import {GuildTreasuryVaultV2} from "../../src/vault/GuildTreasuryVaultV2.sol";

contract GuildTreasuryVaultAdditionalTest is Test {
    address internal owner = makeAddr("owner");
    address internal feeRecipient = makeAddr("feeRecipient");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    GoldToken internal asset;
    GuildTreasuryVaultV1 internal vaultV1;
    GuildTreasuryVaultV2 internal vaultV2;

    function setUp() external {
        asset = new GoldToken(address(this), address(this), 1_000_000 ether);
        asset.transfer(alice, 20_000 ether);
        asset.transfer(bob, 20_000 ether);

        GuildTreasuryVaultV1 implementationV1 = new GuildTreasuryVaultV1();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementationV1),
            abi.encodeCall(GuildTreasuryVaultV1.initialize, (IERC20(address(asset)), owner, feeRecipient))
        );

        vaultV1 = GuildTreasuryVaultV1(address(proxy));

        vm.prank(alice);
        asset.approve(address(vaultV1), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vaultV1), type(uint256).max);

        vm.prank(alice);
        vaultV1.deposit(5_000 ether, alice);

        GuildTreasuryVaultV2 implementationV2 = new GuildTreasuryVaultV2();
        vm.prank(owner);
        vaultV1.upgradeToAndCall(address(implementationV2), "");
        vaultV2 = GuildTreasuryVaultV2(address(vaultV1));
    }

    function testV1InitializationViewsAndFeeRecipientSetter() external {
        assertEq(vaultV1.feeRecipient(), feeRecipient);
        assertEq(vaultV1.accruedFees(), 0);
        assertEq(vaultV1.decimals(), asset.decimals());

        vm.prank(owner);
        vaultV1.setFeeRecipient(bob);
        assertEq(vaultV1.feeRecipient(), bob);
    }

    function testV1CollectFeesTransfersAccruedAmount() external {
        vm.prank(owner);
        vaultV2.setWithdrawalFeeBps(500);

        vm.prank(alice);
        vaultV2.withdraw(100 ether, alice, alice);

        uint256 expectedFees = vaultV2.accruedFees();
        uint256 ownerBefore = asset.balanceOf(owner);

        vm.prank(owner);
        uint256 collected = vaultV1.collectFees(owner);

        assertEq(collected, expectedFees);
        assertEq(asset.balanceOf(owner) - ownerBefore, expectedFees);
        assertEq(vaultV1.accruedFees(), 0);
    }

    function testV2DepositCapViewsAndEnforcement() external {
        assertEq(vaultV2.maxDeposit(alice), type(uint256).max);

        vm.prank(owner);
        vaultV2.setDepositCap(5_500 ether);
        assertEq(vaultV2.maxDeposit(alice), 500 ether);

        vm.prank(bob);
        vaultV2.deposit(500 ether, bob);
        assertEq(vaultV2.maxDeposit(alice), 0);

        vm.expectRevert();
        vm.prank(bob);
        vaultV2.deposit(1 ether, bob);
    }

    function testV2PreviewRedeemPreviewWithdrawAndInvalidFee() external {
        assertEq(vaultV2.previewWithdraw(100 ether), 100 ether);
        assertEq(vaultV2.previewRedeem(100 ether), 100 ether);

        vm.prank(owner);
        vaultV2.setWithdrawalFeeBps(1_000);

        uint256 sharesNeeded = vaultV2.previewWithdraw(100 ether);
        uint256 netAssets = vaultV2.previewRedeem(100 ether);

        assertGt(sharesNeeded, 100 ether);
        assertEq(netAssets, 90 ether);

        vm.expectRevert(bytes("INVALID_FEE_BPS"));
        vm.prank(owner);
        vaultV2.setWithdrawalFeeBps(10_000);
    }

    function testUnauthorizedOwnerFunctionsRevert() external {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        vaultV1.setFeeRecipient(alice);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        vaultV2.setDepositCap(1);
    }
}
