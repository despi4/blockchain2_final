// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {GuildTreasuryVaultV1} from "../../src/vault/GuildTreasuryVaultV1.sol";

contract VaultHandler is Test {
    GoldToken public gold;
    GuildTreasuryVaultV1 public vault;

    constructor(GoldToken gold_, GuildTreasuryVaultV1 vault_) {
        gold = gold_;
        vault = vault_;
        gold.approve(address(vault), type(uint256).max);
    }

    function deposit(uint256 assets) external {
        assets = bound(assets, 1, 1_000 ether);
        gold.mint(address(this), assets);
        try vault.deposit(assets, address(this)) {} catch {}
    }

    function withdraw(uint256 assets) external {
        uint256 maxAssets = vault.maxWithdraw(address(this));
        if (maxAssets == 0) return;
        assets = bound(assets, 1, maxAssets);
        try vault.withdraw(assets, address(this), address(this)) {} catch {}
    }
}

contract VaultInvariantTest is Test {
    GoldToken internal gold;
    GuildTreasuryVaultV1 internal vault;
    VaultHandler internal handler;

    function setUp() public {
        gold = new GoldToken(address(this), address(this), 0);
        GuildTreasuryVaultV1 impl = new GuildTreasuryVaultV1();
        bytes memory data = abi.encodeCall(GuildTreasuryVaultV1.initialize, (IERC20(address(gold)), address(this), address(0xFEE)));
        vault = GuildTreasuryVaultV1(address(new ERC1967Proxy(address(impl), data)));

        handler = new VaultHandler(gold, vault);
        gold.grantRole(gold.MINTER_ROLE(), address(handler));
        targetContract(address(handler));
    }

    function invariant_TotalAssetsEqualsVaultGoldBalance() public view {
        assertEq(gold.balanceOf(address(vault)), vault.totalAssets());
    }

    function invariant_SharesHaveBackingAssets() public view {
        if (vault.totalSupply() > 0) {
            assertGt(vault.totalAssets(), 0);
        }
    }
}
