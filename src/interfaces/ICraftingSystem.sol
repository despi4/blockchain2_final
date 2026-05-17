// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ICraftingSystem {
    function craft(uint256 recipeId, uint256 amount) external;
}
