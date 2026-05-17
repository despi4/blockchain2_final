// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "../../src/libraries/DataTypes.sol";
import {Errors} from "../../src/libraries/Errors.sol";
import {TransferLib} from "../../src/libraries/TransferLib.sol";
import {ValidationLib} from "../../src/libraries/ValidationLib.sol";
import {CraftingMath} from "../../src/math/CraftingMath.sol";
import {ResourceMath} from "../../src/math/ResourceMath.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {IronToken} from "../../src/token/IronToken.sol";
import {ItemRegistry} from "../../src/token/ItemRegistry.sol";
import {ResourceToken} from "../../src/token/ResourceToken.sol";
import {WoodToken} from "../../src/token/WoodToken.sol";
import {RentalEscrow} from "../../src/vault/RentalEscrow.sol";

contract TransferLibHarness {
    function safeTransferNative(address to, uint256 amount) external {
        TransferLib.safeTransferNative(to, amount);
    }

    function safeTransferERC20(address token, address to, uint256 amount) external {
        TransferLib.safeTransferERC20(token, to, amount);
    }

    function safeTransferFromERC20(address token, address from, address to, uint256 amount) external {
        TransferLib.safeTransferFromERC20(token, from, to, amount);
    }

    receive() external payable {}
}

contract ValidationLibHarness {
    function requireNonZero(address account) external pure {
        ValidationLib.requireNonZero(account);
    }

    function requireAmount(uint256 amount) external pure {
        ValidationLib.requireAmount(amount);
    }

    function requireMatchingLengths(uint256 expected, uint256 actual) external pure {
        ValidationLib.requireMatchingLengths(expected, actual);
    }
}

contract CraftingMathHarness {
    function scaleInputs(DataTypes.RecipeInput[] memory inputs, uint256 multiplier)
        external
        pure
        returns (uint256[] memory)
    {
        return CraftingMath.scaleInputs(inputs, multiplier);
    }

    function scaleOutputs(DataTypes.RecipeOutput[] memory outputs, uint256 multiplier)
        external
        pure
        returns (uint256[] memory)
    {
        return CraftingMath.scaleOutputs(outputs, multiplier);
    }
}

contract ResourceMathHarness {
    function quoteLiquidity(uint256 amount0, uint256 amount1, uint112 reserve0, uint112 reserve1)
        external
        pure
        returns (uint256)
    {
        return ResourceMath.quoteLiquidity(amount0, amount1, reserve0, reserve1);
    }

    function getAmountOut(uint256 amountIn, uint112 reserveIn, uint112 reserveOut, uint256 feeBps)
        external
        pure
        returns (uint256)
    {
        return ResourceMath.getAmountOut(amountIn, reserveIn, reserveOut, feeBps);
    }

    function totalLiquidity(uint112 reserve0, uint112 reserve1) external pure returns (uint256) {
        return ResourceMath.totalLiquidity(reserve0, reserve1);
    }
}

contract NativeReceiver {
    receive() external payable {}
}

contract RevertingNativeReceiver {
    receive() external payable {
        revert("NO_NATIVE");
    }
}

contract SupportContractsTest is Test {
    address internal admin = makeAddr("admin");
    address internal user = makeAddr("user");
    address internal stranger = makeAddr("stranger");

    TransferLibHarness internal transferHarness;
    ValidationLibHarness internal validationHarness;
    CraftingMathHarness internal craftingMathHarness;
    ResourceMathHarness internal resourceMathHarness;
    GoldToken internal gold;

    function setUp() external {
        transferHarness = new TransferLibHarness();
        validationHarness = new ValidationLibHarness();
        craftingMathHarness = new CraftingMathHarness();
        resourceMathHarness = new ResourceMathHarness();
        gold = new GoldToken(address(this), address(this), 1_000_000 ether);
    }

    function testValidationLibAcceptsValidValues() external view {
        validationHarness.requireNonZero(user);
        validationHarness.requireAmount(1);
        validationHarness.requireMatchingLengths(2, 2);
    }

    function testValidationLibRevertsOnInvalidValues() external {
        vm.expectRevert(Errors.ZeroAddress.selector);
        validationHarness.requireNonZero(address(0));

        vm.expectRevert(Errors.ZeroAmount.selector);
        validationHarness.requireAmount(0);

        vm.expectRevert(Errors.InvalidArrayLength.selector);
        validationHarness.requireMatchingLengths(1, 2);
    }

    function testTransferLibTransfersNativeAndERC20() external {
        NativeReceiver receiver = new NativeReceiver();

        vm.deal(address(transferHarness), 5 ether);
        transferHarness.safeTransferNative(address(receiver), 1 ether);
        assertEq(address(receiver).balance, 1 ether);

        gold.transfer(address(transferHarness), 100 ether);
        transferHarness.safeTransferERC20(address(gold), user, 40 ether);
        assertEq(gold.balanceOf(user), 40 ether);

        gold.approve(address(transferHarness), 60 ether);
        transferHarness.safeTransferFromERC20(address(gold), address(this), user, 60 ether);
        assertEq(gold.balanceOf(user), 100 ether);
    }

    function testTransferLibRevertsWhenNativeTransferFails() external {
        RevertingNativeReceiver receiver = new RevertingNativeReceiver();

        vm.deal(address(transferHarness), 1 ether);
        vm.expectRevert(bytes("NATIVE_TRANSFER_FAILED"));
        transferHarness.safeTransferNative(address(receiver), 1 ether);
    }

    function testCraftingMathScalesInputsAndOutputs() external view {
        DataTypes.RecipeInput[] memory inputs = new DataTypes.RecipeInput[](2);
        inputs[0] = DataTypes.RecipeInput({asset: address(gold), id: 1, amount: 3, isERC1155: true});
        inputs[1] = DataTypes.RecipeInput({asset: address(gold), id: 2, amount: 5, isERC1155: true});

        DataTypes.RecipeOutput[] memory outputs = new DataTypes.RecipeOutput[](2);
        outputs[0] = DataTypes.RecipeOutput({itemId: 7, amount: 2});
        outputs[1] = DataTypes.RecipeOutput({itemId: 8, amount: 9});

        uint256[] memory scaledInputs = craftingMathHarness.scaleInputs(inputs, 4);
        uint256[] memory scaledOutputs = craftingMathHarness.scaleOutputs(outputs, 3);

        assertEq(scaledInputs.length, 2);
        assertEq(scaledInputs[0], 12);
        assertEq(scaledInputs[1], 20);
        assertEq(scaledOutputs.length, 2);
        assertEq(scaledOutputs[0], 6);
        assertEq(scaledOutputs[1], 27);
    }

    function testResourceMathHandlesBootstrapAndQuotes() external view {
        assertEq(resourceMathHarness.totalLiquidity(81, 100), 90);
        assertEq(resourceMathHarness.quoteLiquidity(100 ether, 25 ether, 0, 0), 50 ether);
        assertEq(resourceMathHarness.quoteLiquidity(50 ether, 200 ether, 100, 400), 100 ether);

        uint256 expectedOut = resourceMathHarness.getAmountOut(10 ether, 100 ether, 200 ether, 30);
        assertGt(expectedOut, 0);
        assertLt(expectedOut, 200 ether);
    }

    function testItemRegistryStoresAndReturnsConfig() external {
        ItemRegistry registry = new ItemRegistry(admin);
        DataTypes.ItemConfig memory config = DataTypes.ItemConfig({
            category: DataTypes.ItemCategory.Equipment,
            craftable: true,
            lootable: false,
            rentable: true,
            metadataURI: "ipfs://sword"
        });

        vm.prank(admin);
        registry.setItemConfig(4, config);

        DataTypes.ItemConfig memory stored = registry.getItemConfig(4);
        assertEq(uint256(stored.category), uint256(DataTypes.ItemCategory.Equipment));
        assertTrue(stored.craftable);
        assertFalse(stored.lootable);
        assertTrue(stored.rentable);
        assertEq(stored.metadataURI, "ipfs://sword");
    }

    function testItemRegistryRejectsUnauthorizedRegistrar() external {
        ItemRegistry registry = new ItemRegistry(admin);
        DataTypes.ItemConfig memory config = DataTypes.ItemConfig({
            category: DataTypes.ItemCategory.Resource,
            craftable: false,
            lootable: true,
            rentable: false,
            metadataURI: "ipfs://wood"
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, registry.REGISTRAR_ROLE()
            )
        );
        vm.prank(stranger);
        registry.setItemConfig(1, config);
    }

    function testResourceTokenSupportsRoleGatedMintAndBurn() external {
        ResourceToken resource = new ResourceToken("Crystal", "CRY", admin);

        vm.prank(admin);
        resource.mint(user, 25 ether);
        assertEq(resource.balanceOf(user), 25 ether);

        vm.prank(admin);
        resource.burnFrom(user, 10 ether);
        assertEq(resource.balanceOf(user), 15 ether);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, resource.MINTER_ROLE())
        );
        vm.prank(stranger);
        resource.mint(user, 1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, resource.BURNER_ROLE())
        );
        vm.prank(stranger);
        resource.burnFrom(user, 1 ether);
    }

    function testWoodAndIronTokensCoverMintAndBurn() external {
        WoodToken wood = new WoodToken(admin, user, 100 ether);
        IronToken iron = new IronToken(admin, user, 200 ether);

        assertEq(wood.balanceOf(user), 100 ether);
        assertEq(iron.balanceOf(user), 200 ether);

        vm.prank(admin);
        wood.mint(stranger, 5 ether);
        assertEq(wood.balanceOf(stranger), 5 ether);

        vm.prank(user);
        wood.burn(10 ether);
        assertEq(wood.balanceOf(user), 90 ether);

        vm.prank(admin);
        iron.mint(stranger, 7 ether);
        assertEq(iron.balanceOf(stranger), 7 ether);

        vm.prank(user);
        iron.burn(20 ether);
        assertEq(iron.balanceOf(user), 180 ether);
    }

    function testRentalEscrowReceivesAndReleasesNative() external {
        RentalEscrow escrow = new RentalEscrow(admin);

        vm.deal(user, 3 ether);
        vm.prank(user);
        (bool success,) = address(escrow).call{value: 2 ether}("");
        assertTrue(success);
        assertEq(address(escrow).balance, 2 ether);

        uint256 adminBefore = admin.balance;
        vm.prank(admin);
        escrow.releaseNative(admin, 1.5 ether);
        assertEq(admin.balance - adminBefore, 1.5 ether);
        assertEq(address(escrow).balance, 0.5 ether);
    }

    function testRentalEscrowRejectsUnauthorizedRelease() external {
        RentalEscrow escrow = new RentalEscrow(admin);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vm.prank(stranger);
        escrow.releaseNative(stranger, 1);
    }
}
