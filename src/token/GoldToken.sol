// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title GoldToken
/// @notice Main fungible in-game resource token used by the AMM and treasury vault.
contract GoldToken is ERC20, ERC20Burnable, AccessControl {
    /// @notice Role allowed to mint new GOLD.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @param admin Address that receives admin and minter roles.
    /// @param initialRecipient Address that receives the initial token supply.
    /// @param initialSupply Initial token supply minted on deployment.
    constructor(address admin, address initialRecipient, uint256 initialSupply) ERC20("Gold Token", "GOLD") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _mint(initialRecipient, initialSupply);
    }

    /// @notice Mints new GOLD tokens.
    /// @param to Recipient of minted tokens.
    /// @param amount Amount of tokens to mint.
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
