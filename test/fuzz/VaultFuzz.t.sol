// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {GuildTreasuryVaultV1} from "../../src/vault/GuildTreasuryVaultV1.sol";

contract VaultFuzzTest is Test {
    GoldToken internal gold;
    GuildTreasuryVaultV1 internal vault;
    address internal user = address(0xB0B);

    function setUp() public {
        gold = new GoldToken(address(this), address(this), 2_000_000 ether);
        GuildTreasuryVaultV1 impl = new GuildTreasuryVaultV1();
        bytes memory data = abi.encodeCall(GuildTreasuryVaultV1.initialize, (IERC20(address(gold)), address(this), address(0xFEE)));
        vault = GuildTreasuryVaultV1(address(new ERC1967Proxy(address(impl), data)));

        gold.mint(user, 100_000 ether);
        vm.prank(user);
        gold.approve(address(vault), type(uint256).max);
    }

    function testFuzz_VaultDeposit(uint256 assets) public {
        assets = bound(assets, 1, 10_000 ether);

        vm.prank(user);
        uint256 shares = vault.deposit(assets, user);

        assertGt(shares, 0);
        assertEq(vault.balanceOf(user), shares);
        assertEq(vault.totalAssets(), assets);
    }

    function testFuzz_VaultWithdraw(uint256 assets) public {
        assets = bound(assets, 2, 10_000 ether);

        vm.startPrank(user);
        vault.deposit(assets, user);
        uint256 withdrawAmount = bound(assets / 2, 1, assets);
        uint256 balanceBefore = gold.balanceOf(user);
        vault.withdraw(withdrawAmount, user, user);
        vm.stopPrank();

        assertEq(gold.balanceOf(user), balanceBefore + withdrawAmount);
    }
}
