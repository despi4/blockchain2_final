// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ResourceAMM} from "../amm/ResourceAMM.sol";

library DeterministicAddressLib {
    function predictPoolAddress(address deployer, address token0, address token1, bytes32 salt)
        internal
        pure
        returns (address)
    {
        bytes memory bytecode =
            abi.encodePacked(type(ResourceAMM).creationCode, abi.encode(IERC20(token0), IERC20(token1)));
        return Create2.computeAddress(salt, keccak256(bytecode), deployer);
    }
}
