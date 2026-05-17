// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ICraftingSystem {
    function craft(uint256 recipeId, uint256 amount, address to) external;

    function previewCraft(uint256 recipeId, uint256 amount)
        external
        view
        returns (
            uint256[] memory itemIds,
            uint256[] memory itemAmounts,
            address[] memory resourceTokens,
            uint256[] memory resourceAmounts
        );
}
