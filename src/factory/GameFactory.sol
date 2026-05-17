// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Errors} from "../libraries/Errors.sol";
import {IProtocolFactory} from "../interfaces/IProtocolFactory.sol";
import {ResourceAMM} from "../amm/ResourceAMM.sol";
import {DeterministicAddressLib} from "./DeterministicAddressLib.sol";

/// @title GameFactory
/// @notice Factory contract that deploys ResourceAMM pools using both CREATE and CREATE2.
/// @dev Token addresses are sorted so a pair has a single canonical pool address.
contract GameFactory is IProtocolFactory {
    mapping(bytes32 pairKey => address pool) private _pools;
    mapping(bytes32 salt => bool used) public usedSalts;

    error SaltAlreadyUsed();

    /// @notice Emitted when a pool is deployed with CREATE.
    event PoolCreated(address indexed token0, address indexed token1, address pool);

    /// @notice Emitted when a pool is deployed with CREATE2.
    event PoolCreatedDeterministic(address indexed token0, address indexed token1, address pool, bytes32 indexed salt);

    /// @inheritdoc IProtocolFactory
    function createPool(address tokenA, address tokenB) external returns (address pool) {
        (address token0, address token1) = _sort(tokenA, tokenB);
        bytes32 key = _pairKey(token0, token1);
        if (_pools[key] != address(0)) revert Errors.PoolExists();

        pool = address(new ResourceAMM(IERC20(token0), IERC20(token1)));
        _pools[key] = pool;

        emit PoolCreated(token0, token1, pool);
    }

    /// @inheritdoc IProtocolFactory
    function createPoolDeterministic(address tokenA, address tokenB, bytes32 salt) external returns (address pool) {
        (address token0, address token1) = _sort(tokenA, tokenB);
        bytes32 key = _pairKey(token0, token1);
        if (_pools[key] != address(0)) revert Errors.PoolExists();
        if (usedSalts[salt]) revert SaltAlreadyUsed();

        pool = address(new ResourceAMM{salt: salt}(IERC20(token0), IERC20(token1)));
        _pools[key] = pool;
        usedSalts[salt] = true;

        emit PoolCreatedDeterministic(token0, token1, pool, salt);
    }

    /// @inheritdoc IProtocolFactory
    function predictPoolAddress(address tokenA, address tokenB, bytes32 salt) external view returns (address predicted) {
        (address token0, address token1) = _sort(tokenA, tokenB);
        return DeterministicAddressLib.predictPoolAddress(address(this), token0, token1, salt);
    }

    /// @inheritdoc IProtocolFactory
    function getPool(address tokenA, address tokenB) external view returns (address pool) {
        (address token0, address token1) = _sort(tokenA, tokenB);
        return _pools[_pairKey(token0, token1)];
    }

    function _pairKey(address token0, address token1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1));
    }

    function _sort(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == address(0) || tokenB == address(0) || tokenA == tokenB) revert Errors.InvalidAsset();
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
