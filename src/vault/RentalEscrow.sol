// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TransferLib} from "../libraries/TransferLib.sol";

contract RentalEscrow is Ownable {
    constructor(address controller) Ownable(controller) {}

    receive() external payable {}

    function releaseNative(address to, uint256 amount) external onlyOwner {
        TransferLib.safeTransferNative(to, amount);
    }
}
