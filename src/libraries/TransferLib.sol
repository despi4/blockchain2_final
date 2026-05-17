// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library TransferLib {
    using SafeERC20 for IERC20;

    function safeTransferNative(address to, uint256 amount) internal {
        (bool success,) = to.call{value: amount}("");
        require(success, "NATIVE_TRANSFER_FAILED");
    }

    function safeTransferERC20(address token, address to, uint256 amount) internal {
        IERC20(token).safeTransfer(to, amount);
    }

    function safeTransferFromERC20(address token, address from, address to, uint256 amount) internal {
        IERC20(token).safeTransferFrom(from, to, amount);
    }
}
