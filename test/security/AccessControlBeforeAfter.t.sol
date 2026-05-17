// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VulnerableGameConfig {
    uint256 public craftingFee;

    // Vulnerability: anyone can change a critical protocol parameter.
    function setCraftingFee(uint256 newCraftingFee) external {
        craftingFee = newCraftingFee;
    }
}

contract FixedGameConfig is Ownable {
    uint256 public craftingFee;

    constructor(address owner_) Ownable(owner_) {}

    function setCraftingFee(uint256 newCraftingFee) external onlyOwner {
        craftingFee = newCraftingFee;
    }
}

contract AccessControlBeforeAfterTest is Test {
    address internal admin = address(0xA11CE);
    address internal attacker = address(0xBAD);

    function testBefore_AttackerCanChangeCraftingFee() public {
        VulnerableGameConfig config = new VulnerableGameConfig();

        vm.prank(attacker);
        config.setCraftingFee(999 ether);

        assertEq(config.craftingFee(), 999 ether);
    }

    function testAfter_AttackerCannotChangeCraftingFee() public {
        FixedGameConfig config = new FixedGameConfig(admin);

        vm.prank(attacker);
        vm.expectRevert();
        config.setCraftingFee(999 ether);

        assertEq(config.craftingFee(), 0);
    }

    function testAfter_AdminCanChangeCraftingFee() public {
        FixedGameConfig config = new FixedGameConfig(admin);

        vm.prank(admin);
        config.setCraftingFee(1 ether);

        assertEq(config.craftingFee(), 1 ether);
    }
}
