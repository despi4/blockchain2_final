// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DataTypes} from "../libraries/DataTypes.sol";

library CraftingMath {
    function scaleInputs(DataTypes.RecipeInput[] memory inputs, uint256 multiplier)
        internal
        pure
        returns (uint256[] memory scaledAmounts)
    {
        scaledAmounts = new uint256[](inputs.length);
        for (uint256 i = 0; i < inputs.length; ++i) {
            scaledAmounts[i] = inputs[i].amount * multiplier;
        }
    }

    function scaleOutputs(DataTypes.RecipeOutput[] memory outputs, uint256 multiplier)
        internal
        pure
        returns (uint256[] memory scaledAmounts)
    {
        scaledAmounts = new uint256[](outputs.length);
        for (uint256 i = 0; i < outputs.length; ++i) {
            scaledAmounts[i] = outputs[i].amount * multiplier;
        }
    }
}
