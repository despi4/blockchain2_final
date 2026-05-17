// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ICraftingSystem} from "../interfaces/ICraftingSystem.sol";
import {IGameItems1155} from "../interfaces/IGameItems1155.sol";

/// @title CraftingSystem
/// @notice Burns required ERC1155 inputs and mints crafted ERC1155 outputs.
/// @dev This contract must be granted `BURNER_ROLE` and `MINTER_ROLE` on `GameItems`.
contract CraftingSystem is ICraftingSystem, AccessControl, Pausable, ReentrancyGuard {
    /// @notice Role allowed to manage recipes and pause state.
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Reference to the game items ERC1155 contract.
    IGameItems1155 public immutable gameItems;

    /// @notice Crafting recipe definition.
    struct Recipe {
        uint256[] inputItemIds;
        uint256[] inputAmounts;
        uint256 outputItemId;
        uint256 outputAmount;
        bool active;
    }

    /// @notice Reverts when a recipe is not active.
    error RecipeInactive(uint256 recipeId);

    /// @notice Reverts when a recipe configuration is invalid.
    error InvalidRecipe();

    /// @notice Reverts when crafting amount is zero.
    error ZeroCraftAmount();

    /// @notice Reverts when input arrays have mismatched lengths.
    error InvalidInputLengths();

    mapping(uint256 recipeId => Recipe recipe) private _recipes;

    /// @notice Emitted when a recipe is created or updated.
    event RecipeSet(
        uint256 indexed recipeId,
        uint256[] inputItemIds,
        uint256[] inputAmounts,
        uint256 outputItemId,
        uint256 outputAmount,
        bool active
    );

    /// @notice Emitted when a recipe is disabled.
    event RecipeDisabled(uint256 indexed recipeId);

    /// @notice Emitted when a player crafts items.
    event Crafted(
        address indexed user,
        uint256 indexed recipeId,
        uint256 amount,
        uint256 indexed outputItemId,
        uint256 outputAmount
    );

    /// @param admin Address that receives admin and manager roles.
    /// @param gameItems_ ERC1155 items contract used for input burns and output mints.
    constructor(address admin, IGameItems1155 gameItems_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, admin);
        gameItems = gameItems_;
    }

    /// @notice Creates or updates a crafting recipe.
    /// @param recipeId Unique recipe identifier.
    /// @param inputItemIds Array of required input item ids.
    /// @param inputAmounts Array of required input amounts.
    /// @param outputItemId Crafted output item id.
    /// @param outputAmount Crafted output amount per craft.
    /// @param active Whether the recipe should be immediately craftable.
    function setRecipe(
        uint256 recipeId,
        uint256[] calldata inputItemIds,
        uint256[] calldata inputAmounts,
        uint256 outputItemId,
        uint256 outputAmount,
        bool active
    ) external onlyRole(MANAGER_ROLE) {
        if (inputItemIds.length == 0 || inputItemIds.length != inputAmounts.length) revert InvalidInputLengths();
        if (outputItemId == 0 || outputAmount == 0) revert InvalidRecipe();

        for (uint256 i = 0; i < inputAmounts.length; ++i) {
            if (inputItemIds[i] == 0 || inputAmounts[i] == 0) revert InvalidRecipe();
        }

        Recipe storage recipe = _recipes[recipeId];
        recipe.inputItemIds = inputItemIds;
        recipe.inputAmounts = inputAmounts;
        recipe.outputItemId = outputItemId;
        recipe.outputAmount = outputAmount;
        recipe.active = active;

        emit RecipeSet(recipeId, inputItemIds, inputAmounts, outputItemId, outputAmount, active);
    }

    /// @notice Disables an existing recipe.
    /// @param recipeId Recipe identifier to disable.
    function disableRecipe(uint256 recipeId) external onlyRole(MANAGER_ROLE) {
        Recipe storage recipe = _recipes[recipeId];
        if (recipe.outputAmount == 0) revert InvalidRecipe();
        recipe.active = false;
        emit RecipeDisabled(recipeId);
    }

    /// @notice Burns recipe inputs from the caller and mints crafted outputs to the caller.
    /// @param recipeId Recipe identifier to execute.
    /// @param amount Number of times to execute the recipe.
    function craft(uint256 recipeId, uint256 amount) external override whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroCraftAmount();

        Recipe storage recipe = _recipes[recipeId];
        if (!recipe.active) revert RecipeInactive(recipeId);

        uint256[] memory scaledInputAmounts = new uint256[](recipe.inputAmounts.length);
        for (uint256 i = 0; i < recipe.inputAmounts.length; ++i) {
            scaledInputAmounts[i] = recipe.inputAmounts[i] * amount;
        }

        gameItems.burnBatch(msg.sender, recipe.inputItemIds, scaledInputAmounts);

        uint256 mintedAmount = recipe.outputAmount * amount;
        gameItems.mint(msg.sender, recipe.outputItemId, mintedAmount, "");

        emit Crafted(msg.sender, recipeId, amount, recipe.outputItemId, mintedAmount);
    }

    /// @notice Returns recipe configuration.
    /// @param recipeId Recipe identifier to query.
    function getRecipe(uint256 recipeId)
        external
        view
        returns (
            uint256[] memory inputItemIds,
            uint256[] memory inputAmounts,
            uint256 outputItemId,
            uint256 outputAmount,
            bool active
        )
    {
        Recipe storage recipe = _recipes[recipeId];
        return (recipe.inputItemIds, recipe.inputAmounts, recipe.outputItemId, recipe.outputAmount, recipe.active);
    }

    /// @notice Pauses crafting.
    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }

    /// @notice Unpauses crafting.
    function unpause() external onlyRole(MANAGER_ROLE) {
        _unpause();
    }
}
