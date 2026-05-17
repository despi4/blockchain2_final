// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

contract RecipeRegistry is Ownable {
    struct Recipe {
        DataTypes.RecipeInput[] inputs;
        DataTypes.RecipeOutput[] outputs;
        uint64 cooldown;
        bool enabled;
    }

    mapping(uint256 recipeId => Recipe recipe) private _recipes;

    event RecipeConfigured(uint256 indexed recipeId, uint64 cooldown, bool enabled);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setRecipe(
        uint256 recipeId,
        DataTypes.RecipeInput[] calldata inputs,
        DataTypes.RecipeOutput[] calldata outputs,
        uint64 cooldown,
        bool enabled
    ) external onlyOwner {
        delete _recipes[recipeId].inputs;
        delete _recipes[recipeId].outputs;

        for (uint256 i = 0; i < inputs.length; ++i) {
            _recipes[recipeId].inputs.push(inputs[i]);
        }
        for (uint256 i = 0; i < outputs.length; ++i) {
            _recipes[recipeId].outputs.push(outputs[i]);
        }
        _recipes[recipeId].cooldown = cooldown;
        _recipes[recipeId].enabled = enabled;

        emit RecipeConfigured(recipeId, cooldown, enabled);
    }

    function getRecipe(uint256 recipeId)
        external
        view
        returns (
            DataTypes.RecipeInput[] memory inputs,
            DataTypes.RecipeOutput[] memory outputs,
            uint64 cooldown,
            bool enabled
        )
    {
        Recipe storage recipe = _recipes[recipeId];
        return (recipe.inputs, recipe.outputs, recipe.cooldown, recipe.enabled);
    }
}
