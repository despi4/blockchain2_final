// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GoldToken} from "../src/token/GoldToken.sol";
import {GuildTreasuryVaultV1} from "../src/vault/GuildTreasuryVaultV1.sol";
import {GuildTreasuryVaultV2} from "../src/vault/GuildTreasuryVaultV2.sol";

contract GuildTreasuryVaultV2Test is Test {
    GoldToken internal asset;
    GuildTreasuryVaultV1 internal vaultV1;
    GuildTreasuryVaultV2 internal vaultV2;

    function setUp() external {
        asset = new GoldToken(address(this), address(this), 1_000_000 ether);

        GuildTreasuryVaultV1 implementationV1 = new GuildTreasuryVaultV1();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementationV1),
            abi.encodeCall(GuildTreasuryVaultV1.initialize, (IERC20(address(asset)), address(this), address(this)))
        );

        vaultV1 = GuildTreasuryVaultV1(address(proxy));
        asset.approve(address(vaultV1), type(uint256).max);
        vaultV1.deposit(1_000 ether, address(this));

        GuildTreasuryVaultV2 implementationV2 = new GuildTreasuryVaultV2();
        vaultV1.upgradeToAndCall(address(implementationV2), "");
        vaultV2 = GuildTreasuryVaultV2(address(proxy));
    }

    function testWithdrawTransfersRequestedAssetsAndAccruesFee() external {
        vaultV2.setWithdrawalFeeBps(1_000);

        uint256 balanceBefore = asset.balanceOf(address(this));
        uint256 sharesNeeded = vaultV2.previewWithdraw(100 ether);

        vaultV2.withdraw(100 ether, address(this), address(this));

        assertEq(asset.balanceOf(address(this)) - balanceBefore, 100 ether);
        assertGt(vaultV2.accruedFees(), 0);
        assertEq(vaultV2.balanceOf(address(this)), 1_000 ether - sharesNeeded);
    }
}
