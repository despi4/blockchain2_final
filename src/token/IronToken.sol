// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title IronToken
/// @notice Secondary resource token used for crafting and AMM pool pairs.
contract IronToken is ERC20, ERC20Burnable, AccessControl {
    /// @notice Role allowed to mint new IRON.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @param admin Address that receives admin and minter roles.
    /// @param initialRecipient Address that receives the initial token supply.
    /// @param initialSupply Initial token supply minted on deployment.
    constructor(address admin, address initialRecipient, uint256 initialSupply) ERC20("Iron Token", "IRON") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _mint(initialRecipient, initialSupply);
    }

    /// @notice Mints new IRON tokens.
    /// @param to Recipient of minted tokens.
    /// @param amount Amount of tokens to mint.
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
