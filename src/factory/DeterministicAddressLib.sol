// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {IProtocolConfig} from "../interfaces/IProtocolConfig.sol";
import {ResourcePool} from "../amm/ResourcePool.sol";

library DeterministicAddressLib {
    function predictPoolAddress(
        address deployer,
        address token0,
        address token1,
        IProtocolConfig protocolConfig,
        bytes32 salt
    ) internal pure returns (address) {
        bytes memory bytecode =
            abi.encodePacked(type(ResourcePool).creationCode, abi.encode(token0, token1, protocolConfig));
        return Create2.computeAddress(salt, keccak256(bytecode), deployer);
    }
}
