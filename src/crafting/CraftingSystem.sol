// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICraftingSystem} from "../interfaces/ICraftingSystem.sol";
import {IGameItems1155} from "../interfaces/IGameItems1155.sol";
import {IProtocolConfig} from "../interfaces/IProtocolConfig.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {RecipeRegistry} from "./RecipeRegistry.sol";

contract CraftingSystem is ICraftingSystem {
    using SafeERC20 for IERC20;

    IGameItems1155 public immutable items;
    IProtocolConfig public immutable protocolConfig;
    RecipeRegistry public immutable recipeRegistry;

    mapping(address user => mapping(uint256 recipeId => uint256 lastCraftAt)) public lastCraftAt;

    event Crafted(address indexed user, uint256 indexed recipeId, uint256 amount, address indexed recipient);

    constructor(IGameItems1155 items_, IProtocolConfig protocolConfig_, RecipeRegistry recipeRegistry_) {
        items = items_;
        protocolConfig = protocolConfig_;
        recipeRegistry = recipeRegistry_;
    }

    function craft(uint256 recipeId, uint256 amount, address to) external override {
        if (!protocolConfig.craftingEnabled(recipeId)) revert Errors.Disabled();

        (DataTypes.RecipeInput[] memory inputs, DataTypes.RecipeOutput[] memory outputs, uint64 cooldown, bool enabled) =
            recipeRegistry.getRecipe(recipeId);
        if (!enabled) revert Errors.Disabled();
        if (cooldown != 0 && block.timestamp < lastCraftAt[msg.sender][recipeId] + cooldown) revert Errors.InvalidConfiguration();

        for (uint256 i = 0; i < inputs.length; ++i) {
            uint256 scaledAmount = inputs[i].amount * amount;
            if (inputs[i].isERC1155) {
                items.burn(msg.sender, inputs[i].id, scaledAmount);
            } else {
                IERC20(inputs[i].asset).safeTransferFrom(msg.sender, address(this), scaledAmount);
            }
        }

        for (uint256 i = 0; i < outputs.length; ++i) {
            items.mint(to, outputs[i].itemId, outputs[i].amount * amount, "");
        }

        lastCraftAt[msg.sender][recipeId] = block.timestamp;
        emit Crafted(msg.sender, recipeId, amount, to);
    }

    function previewCraft(uint256 recipeId, uint256 amount)
        external
        view
        override
        returns (
            uint256[] memory itemIds,
            uint256[] memory itemAmounts,
            address[] memory resourceTokens,
            uint256[] memory resourceAmounts
        )
    {
        (DataTypes.RecipeInput[] memory inputs, DataTypes.RecipeOutput[] memory outputs,,) = recipeRegistry.getRecipe(recipeId);

        itemIds = new uint256[](outputs.length);
        itemAmounts = new uint256[](outputs.length);
        resourceTokens = new address[](inputs.length);
        resourceAmounts = new uint256[](inputs.length);

        for (uint256 i = 0; i < outputs.length; ++i) {
            itemIds[i] = outputs[i].itemId;
            itemAmounts[i] = outputs[i].amount * amount;
        }

        for (uint256 i = 0; i < inputs.length; ++i) {
            resourceTokens[i] = inputs[i].asset;
            resourceAmounts[i] = inputs[i].amount * amount;
        }
    }
}
