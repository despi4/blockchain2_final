// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Errors} from "../../src/libraries/Errors.sol";
import {GameFactory} from "../../src/factory/GameFactory.sol";
import {GoldToken} from "../../src/token/GoldToken.sol";
import {WoodToken} from "../../src/token/WoodToken.sol";
import {IronToken} from "../../src/token/IronToken.sol";

contract GameFactoryTest is Test {
    address internal admin = makeAddr("admin");

    GameFactory internal factory;
    GoldToken internal gold;
    WoodToken internal wood;
    IronToken internal iron;

    function setUp() external {
        factory = new GameFactory();
        gold = new GoldToken(admin, admin, 1_000_000 ether);
        wood = new WoodToken(admin, admin, 1_000_000 ether);
        iron = new IronToken(admin, admin, 1_000_000 ether);
    }

    function testCreatePoolUsingCreate() external {
        address pool = factory.createPool(address(gold), address(wood));

        assertTrue(pool != address(0));
        assertEq(factory.getPool(address(gold), address(wood)), pool);
        assertEq(factory.getPool(address(wood), address(gold)), pool);
    }

    function testCreatePoolUsingCreate2() external {
        bytes32 salt = keccak256("gold-iron");

        address pool = factory.createPoolDeterministic(address(gold), address(iron), salt);

        assertTrue(pool != address(0));
        assertEq(factory.getPool(address(gold), address(iron)), pool);
    }

    function testPredictedAddressEqualsActualDeployedAddress() external {
        bytes32 salt = keccak256("gold-wood");
        address predicted = factory.predictPoolAddress(address(gold), address(wood), salt);

        address deployed = factory.createPoolDeterministic(address(wood), address(gold), salt);

        assertEq(deployed, predicted);
    }

    function testDuplicatePoolReverts() external {
        factory.createPool(address(gold), address(wood));

        vm.expectRevert(Errors.PoolExists.selector);
        factory.createPool(address(wood), address(gold));
    }

    function testReversedTokenOrderReturnsSamePool() external {
        address pool = factory.createPool(address(gold), address(iron));

        assertEq(factory.getPool(address(gold), address(iron)), pool);
        assertEq(factory.getPool(address(iron), address(gold)), pool);
    }

    function testZeroAddressReverts() external {
        vm.expectRevert(Errors.InvalidAsset.selector);
        factory.createPool(address(0), address(wood));
    }

    function testSaltReuseReverts() external {
        bytes32 salt = keccak256("shared-salt");
        factory.createPoolDeterministic(address(gold), address(wood), salt);

        vm.expectRevert(GameFactory.SaltAlreadyUsed.selector);
        factory.createPoolDeterministic(address(gold), address(iron), salt);
    }
}
