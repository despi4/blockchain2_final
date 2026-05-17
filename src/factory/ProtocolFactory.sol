// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Errors} from "../libraries/Errors.sol";
import {IProtocolConfig} from "../interfaces/IProtocolConfig.sol";
import {IProtocolFactory} from "../interfaces/IProtocolFactory.sol";
import {ResourcePool} from "../amm/ResourcePool.sol";
import {ResourceToken} from "../token/ResourceToken.sol";
import {RentalEscrow} from "../vault/RentalEscrow.sol";
import {DeterministicAddressLib} from "./DeterministicAddressLib.sol";

contract ProtocolFactory is Ownable, IProtocolFactory {
    IProtocolConfig public immutable protocolConfig;

    mapping(bytes32 poolKey => address pool) public pools;

    event PoolDeployed(address indexed token0, address indexed token1, address pool, bytes32 salt);
    event ResourceTokenDeployed(address token, string name, string symbol);
    event RentalEscrowDeployed(address escrow, bytes32 salt);

    constructor(address initialOwner, IProtocolConfig protocolConfig_) Ownable(initialOwner) {
        protocolConfig = protocolConfig_;
    }

    function deployPool(address tokenA, address tokenB) external override onlyOwner returns (address pool) {
        (address token0, address token1) = _sort(tokenA, tokenB);
        bytes32 key = _poolKey(token0, token1);
        if (pools[key] != address(0)) revert Errors.PoolExists();

        pool = address(new ResourcePool(token0, token1, protocolConfig));
        pools[key] = pool;
        emit PoolDeployed(token0, token1, pool, bytes32(0));
    }

    function deployPoolDeterministic(address tokenA, address tokenB, bytes32 salt)
        external
        override
        onlyOwner
        returns (address pool)
    {
        (address token0, address token1) = _sort(tokenA, tokenB);
        bytes32 key = _poolKey(token0, token1);
        if (pools[key] != address(0)) revert Errors.PoolExists();

        pool = address(new ResourcePool{salt: salt}(token0, token1, protocolConfig));
        pools[key] = pool;
        emit PoolDeployed(token0, token1, pool, salt);
    }

    function predictPoolAddress(address tokenA, address tokenB, bytes32 salt)
        external
        view
        override
        returns (address predicted)
    {
        (address token0, address token1) = _sort(tokenA, tokenB);
        return DeterministicAddressLib.predictPoolAddress(address(this), token0, token1, protocolConfig, salt);
    }

    function deployResourceToken(string calldata name, string calldata symbol) external onlyOwner returns (address token) {
        token = address(new ResourceToken(name, symbol, owner()));
        emit ResourceTokenDeployed(token, name, symbol);
    }

    function deployRentalEscrow(bytes32 salt) external onlyOwner returns (address escrow) {
        escrow = address(new RentalEscrow{salt: salt}(owner()));
        emit RentalEscrowDeployed(escrow, salt);
    }

    function _poolKey(address token0, address token1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1));
    }

    function _sort(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB || tokenA == address(0) || tokenB == address(0)) revert Errors.InvalidAsset();
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
