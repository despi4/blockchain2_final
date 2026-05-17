// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VulnerableBank {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "NO_BALANCE");

        // Vulnerability: external call before state update.
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "TRANSFER_FAILED");

        balances[msg.sender] = 0;
    }
}

contract FixedBank is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "NO_BALANCE");

        // Fix: effects before interaction + nonReentrant.
        balances[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
    }
}

interface IBank {
    function deposit() external payable;
    function withdraw() external;
}

contract ReentrancyAttacker {
    IBank public bank;
    uint256 public reentered;

    constructor(IBank bank_) {
        bank = bank_;
    }

    function attack() external payable {
        bank.deposit{value: msg.value}();
        bank.withdraw();
    }

    receive() external payable {
        if (address(bank).balance >= 1 ether && reentered < 3) {
            ++reentered;
            bank.withdraw();
        }
    }
}

contract ReentrancyBeforeAfterTest is Test {
    address internal victim = address(0xBEEF);

    function testBefore_ReentrancyAttackSucceeds() public {
        VulnerableBank bank = new VulnerableBank();
        vm.deal(victim, 10 ether);
        vm.prank(victim);
        bank.deposit{value: 10 ether}();

        ReentrancyAttacker attacker = new ReentrancyAttacker(IBank(address(bank)));
        attacker.attack{value: 1 ether}();

        assertGt(address(attacker).balance, 1 ether);
        assertLt(address(bank).balance, 10 ether);
    }

    function testAfter_ReentrancyAttackFails() public {
        FixedBank bank = new FixedBank();
        vm.deal(victim, 10 ether);
        vm.prank(victim);
        bank.deposit{value: 10 ether}();

        ReentrancyAttacker attacker = new ReentrancyAttacker(IBank(address(bank)));
        vm.expectRevert();
        attacker.attack{value: 1 ether}();

        assertEq(address(bank).balance, 10 ether);
    }
}
