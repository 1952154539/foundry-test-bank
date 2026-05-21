// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;

    address public admin;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public attacker;

    function setUp() public {
        admin    = makeAddr("admin");
        user1    = makeAddr("user1");
        user2    = makeAddr("user2");
        user3    = makeAddr("user3");
        user4    = makeAddr("user4");
        attacker = makeAddr("attacker");

        vm.prank(admin);
        bank = new Bank();

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
        vm.deal(attacker, 100 ether);
    }

    // ══════════════════════════════════════════════════════════════════
    // 1. Deposit balance updates
    // ══════════════════════════════════════════════════════════════════

    function test_Deposit_BalanceUpdated() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        assertEq(bank.balances(user1), 1 ether);

        vm.prank(user1);
        bank.deposit{value: 2 ether}();
        assertEq(bank.balances(user1), 3 ether);
    }

    function test_Deposit_ContractBalanceUpdated() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        assertEq(address(bank).balance, 1 ether);

        vm.prank(user2);
        bank.deposit{value: 3 ether}();
        assertEq(address(bank).balance, 4 ether);
    }

    function test_Deposit_EmitsEvent() public {
        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit Bank.Deposited(user1, 1 ether);
        bank.deposit{value: 1 ether}();
    }

    function test_Receive_FallbackFunctionsAsDeposit() public {
        vm.prank(user1);
        (bool ok,) = address(bank).call{value: 0.5 ether}("");
        assertTrue(ok);
        assertEq(bank.balances(user1), 0.5 ether);
    }

    function test_RevertOn_ZeroDeposit() public {
        vm.prank(user1);
        vm.expectRevert("Bank: amount must be greater than zero");
        bank.deposit{value: 0}();
    }

    // ══════════════════════════════════════════════════════════════════
    // 2. Top 3 depositors
    // ══════════════════════════════════════════════════════════════════

    function test_TopDepositors_OneUser() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        address[3] memory top = bank.getTopDepositors();
        assertEq(top[0], user1);
        assertEq(top[1], address(0));
        assertEq(top[2], address(0));
    }

    function test_TopDepositors_TwoUsers() public {
        vm.prank(user1);
        bank.deposit{value: 2 ether}();

        vm.prank(user2);
        bank.deposit{value: 1 ether}();

        address[3] memory top = bank.getTopDepositors();
        assertEq(top[0], user1);
        assertEq(top[1], user2);
        assertEq(top[2], address(0));
    }

    function test_TopDepositors_ThreeUsers() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.prank(user2);
        bank.deposit{value: 3 ether}();

        vm.prank(user3);
        bank.deposit{value: 2 ether}();

        address[3] memory top = bank.getTopDepositors();
        assertEq(top[0], user2); // 3 eth
        assertEq(top[1], user3); // 2 eth
        assertEq(top[2], user1); // 1 eth
    }

    function test_TopDepositors_FourUsers() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.prank(user2);
        bank.deposit{value: 4 ether}();

        vm.prank(user3);
        bank.deposit{value: 2 ether}();

        vm.prank(user4);
        bank.deposit{value: 3 ether}();

        address[3] memory top = bank.getTopDepositors();
        // Expected order: user2(4), user4(3), user3(2)
        assertEq(top[0], user2);
        assertEq(top[1], user4);
        assertEq(top[2], user3);

        // user1 (1 ether) must not be in top 3
        assertFalse(top[0] == user1 || top[1] == user1 || top[2] == user1);
    }

    function test_TopDepositors_SameUserMultipleDeposits() public {
        // user1 deposits 1 eth
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        // user2 deposits 2 eth
        vm.prank(user2);
        bank.deposit{value: 2 ether}();

        // user3 deposits 3 eth  =>  top: user3(3), user2(2), user1(1)
        vm.prank(user3);
        bank.deposit{value: 3 ether}();

        // user1 deposits 3 more  =>  user1 total = 4 eth, should become #1
        vm.prank(user1);
        bank.deposit{value: 3 ether}();

        address[3] memory top = bank.getTopDepositors();
        assertEq(bank.balances(user1), 4 ether);
        assertEq(top[0], user1); // 4 eth
        assertEq(top[1], user3); // 3 eth
        assertEq(top[2], user2); // 2 eth
    }

    // ══════════════════════════════════════════════════════════════════
    // 3. Admin-only withdrawal
    // ══════════════════════════════════════════════════════════════════

    function test_Withdraw_AdminCanWithdraw() public {
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        uint256 balBefore = admin.balance;
        vm.prank(admin);
        bank.withdraw(2 ether);

        assertEq(address(bank).balance, 3 ether);
        assertEq(admin.balance, balBefore + 2 ether);
    }

    function test_Withdraw_NonAdminReverts() public {
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        vm.prank(attacker);
        vm.expectRevert("Bank: caller is not the admin");
        bank.withdraw(1 ether);
    }

    function test_Withdraw_NonAdminCannotWithdrawEvenIfDepositor() public {
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        // user1 deposited but is not admin — must not be able to withdraw
        vm.prank(user1);
        vm.expectRevert("Bank: caller is not the admin");
        bank.withdraw(1 ether);
    }

    function test_Withdraw_RevertsOnZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert("Bank: amount must be greater than zero");
        bank.withdraw(0);
    }

    function test_Withdraw_RevertsOnInsufficientBalance() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.prank(admin);
        vm.expectRevert("Bank: insufficient contract balance");
        bank.withdraw(2 ether);
    }

    function test_Withdraw_EmitsEvent() public {
        vm.prank(user1);
        bank.deposit{value: 2 ether}();

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit Bank.Withdrawn(admin, 1 ether);
        bank.withdraw(1 ether);
    }
}
