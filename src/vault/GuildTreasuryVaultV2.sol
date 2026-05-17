// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {GuildTreasuryVaultV1} from "./GuildTreasuryVaultV1.sol";

contract GuildTreasuryVaultV2 is GuildTreasuryVaultV1 {
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    event DepositCapUpdated(uint256 depositCap);
    event WithdrawalFeeUpdated(uint256 withdrawalFeeBps);

    function setDepositCap(uint256 depositCap_) external onlyOwner {
        _depositCap = depositCap_;
        emit DepositCapUpdated(depositCap_);
    }

    function setWithdrawalFeeBps(uint256 withdrawalFeeBps_) external onlyOwner {
        require(withdrawalFeeBps_ < BPS_DENOMINATOR, "INVALID_FEE_BPS");
        _withdrawalFeeBps = withdrawalFeeBps_;
        emit WithdrawalFeeUpdated(withdrawalFeeBps_);
    }

    function maxDeposit(address) public view override returns (uint256) {
        if (_depositCap == 0) {
            return type(uint256).max;
        }
        uint256 currentAssets = totalAssets();
        if (currentAssets >= _depositCap) {
            return 0;
        }
        return _depositCap - currentAssets;
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 grossAssets = _grossUp(assets);
        return super.previewWithdraw(grossAssets);
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 grossAssets = super.previewRedeem(shares);
        uint256 fee = Math.mulDiv(grossAssets, _withdrawalFeeBps, BPS_DENOMINATOR, Math.Rounding.Floor);
        return grossAssets - fee;
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        uint256 fee = _grossUp(assets) - assets;
        _accruedFees += fee;
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    function _grossUp(uint256 assets) internal view returns (uint256) {
        if (_withdrawalFeeBps == 0) {
            return assets;
        }
        return Math.mulDiv(assets, BPS_DENOMINATOR, BPS_DENOMINATOR - _withdrawalFeeBps, Math.Rounding.Ceil);
    }
}
