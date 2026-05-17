// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {VaultStorage} from "../upgrade/VaultStorage.sol";

contract GuildTreasuryVaultV1 is
    Initializable,
    ERC20Upgradeable,
    ERC4626Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    VaultStorage
{
    using SafeERC20 for IERC20;

    event FeeRecipientUpdated(address indexed feeRecipient);

    function initialize(IERC20 asset_, address owner_, address feeRecipient_) external initializer {
        __ERC20_init("Guild Treasury Share", "gSHARE");
        __ERC4626_init(asset_);
        __Ownable_init(owner_);
        _feeRecipient = feeRecipient_;
    }

    function feeRecipient() external view returns (address) {
        return _feeRecipient;
    }

    function accruedFees() external view returns (uint256) {
        return _accruedFees;
    }

    function decimals() public view override(ERC20Upgradeable, ERC4626Upgradeable) returns (uint8) {
        return super.decimals();
    }

    function setFeeRecipient(address feeRecipient_) external onlyOwner {
        _feeRecipient = feeRecipient_;
        emit FeeRecipientUpdated(feeRecipient_);
    }

    function collectFees(address to) external onlyOwner returns (uint256 amount) {
        amount = _accruedFees;
        _accruedFees = 0;
        IERC20(asset()).safeTransfer(to, amount);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
