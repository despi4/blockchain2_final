// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ResourceLPToken
/// @notice LP token minted and burned exclusively by a paired ResourceAMM.
contract ResourceLPToken is ERC20 {
    /// @notice AMM contract allowed to mint and burn LP tokens.
    address public immutable amm;

    error OnlyAMM();

    constructor(address amm_, string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        amm = amm_;
    }

    modifier onlyAMM() {
        if (msg.sender != amm) revert OnlyAMM();
        _;
    }

    /// @notice Mints LP tokens to a liquidity provider.
    function mint(address to, uint256 amount) external onlyAMM {
        _mint(to, amount);
    }

    /// @notice Burns LP tokens from a liquidity provider.
    function burn(address from, uint256 amount) external onlyAMM {
        _burn(from, amount);
    }
}
