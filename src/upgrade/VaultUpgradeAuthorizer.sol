// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Errors} from "../libraries/Errors.sol";

abstract contract VaultUpgradeAuthorizer {
    function owner() public view virtual returns (address);

    modifier onlyUpgradeAdmin() {
        if (owner() != _msgSender()) revert Errors.UpgradeDenied();
        _;
    }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}
