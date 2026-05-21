// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenBank, IERC20} from "../src/TokenBank.sol";

contract TokenBankTest is Test {
    TokenBank public tokenBank;

    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address public user;
    address public user2;

    uint256 public constant DEPOSIT_AMOUNT = 1000 * 10 ** 6; // 1,000 USDT
    uint256 public constant WITHDRAW_AMOUNT = 300 * 10 ** 6; //   300 USDT

    function setUp() public {
        user  = makeAddr("user");
        user2 = makeAddr("user2");

        // Fork Ethereum mainnet at the latest block.
        vm.createSelectFork("mainnet");

        tokenBank = new TokenBank(USDT);

        // Use deal to directly assign USDT balances (bypasses need for a funded holder).
        deal(USDT, user, DEPOSIT_AMOUNT * 2);
        deal(USDT, user2, DEPOSIT_AMOUNT);

        // Approve TokenBank to spend user's USDT.
        // USDT does NOT return a bool from approve — use low-level call.
        vm.prank(user);
        _approveUSDT(address(tokenBank), type(uint256).max);

        vm.prank(user2);
        _approveUSDT(address(tokenBank), type(uint256).max);
    }

    /// @dev Low-level approve — USDT returns void, so a standard IERC20 interface call reverts.
    function _approveUSDT(address spender, uint256 amount) private {
        (bool ok,) = USDT.call(abi.encodeWithSignature("approve(address,uint256)", spender, amount));
        require(ok, "USDT approve failed");
    }

    // ══════════════════════════════════════════════════════════════════
    // Deposit
    // ══════════════════════════════════════════════════════════════════

    function test_Deposit_USDT() public {
        uint256 balBefore = IERC20(USDT).balanceOf(user);

        vm.prank(user);
        tokenBank.deposit(DEPOSIT_AMOUNT);

        assertEq(tokenBank.balances(user), DEPOSIT_AMOUNT);
        assertEq(tokenBank.totalDeposits(), DEPOSIT_AMOUNT);
        assertEq(IERC20(USDT).balanceOf(user), balBefore - DEPOSIT_AMOUNT);
        assertEq(IERC20(USDT).balanceOf(address(tokenBank)), DEPOSIT_AMOUNT);
    }

    function test_Deposit_EmitsEvent() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit TokenBank.Deposited(user, DEPOSIT_AMOUNT);
        tokenBank.deposit(DEPOSIT_AMOUNT);
    }

    function test_Deposit_MultipleUsers() public {
        vm.prank(user);
        tokenBank.deposit(DEPOSIT_AMOUNT);

        vm.prank(user2);
        tokenBank.deposit(DEPOSIT_AMOUNT);

        assertEq(tokenBank.balances(user), DEPOSIT_AMOUNT);
        assertEq(tokenBank.balances(user2), DEPOSIT_AMOUNT);
        assertEq(tokenBank.totalDeposits(), DEPOSIT_AMOUNT * 2);
    }

    function test_Deposit_RevertsOnZero() public {
        vm.prank(user);
        vm.expectRevert(TokenBank.TokenBank__ZeroAmount.selector);
        tokenBank.deposit(0);
    }

    // ══════════════════════════════════════════════════════════════════
    // Withdraw
    // ══════════════════════════════════════════════════════════════════

    function test_Withdraw_Partial() public {
        vm.prank(user);
        tokenBank.deposit(DEPOSIT_AMOUNT);

        uint256 balBefore = IERC20(USDT).balanceOf(user);

        vm.prank(user);
        tokenBank.withdraw(WITHDRAW_AMOUNT);

        assertEq(tokenBank.balances(user), DEPOSIT_AMOUNT - WITHDRAW_AMOUNT);
        assertEq(tokenBank.totalDeposits(), DEPOSIT_AMOUNT - WITHDRAW_AMOUNT);
        assertEq(IERC20(USDT).balanceOf(user), balBefore + WITHDRAW_AMOUNT);
    }

    function test_Withdraw_All() public {
        vm.prank(user);
        tokenBank.deposit(DEPOSIT_AMOUNT);

        uint256 balBefore = IERC20(USDT).balanceOf(user);

        vm.prank(user);
        tokenBank.withdrawAll();

        assertEq(tokenBank.balances(user), 0);
        assertEq(tokenBank.totalDeposits(), 0);
        assertEq(IERC20(USDT).balanceOf(user), balBefore + DEPOSIT_AMOUNT);
    }

    function test_Withdraw_EmitsEvent() public {
        vm.prank(user);
        tokenBank.deposit(DEPOSIT_AMOUNT);

        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit TokenBank.Withdrawn(user, WITHDRAW_AMOUNT);
        tokenBank.withdraw(WITHDRAW_AMOUNT);
    }

    function test_Withdraw_RevertsOnZero() public {
        vm.prank(user);
        vm.expectRevert(TokenBank.TokenBank__ZeroAmount.selector);
        tokenBank.withdraw(0);
    }

    function test_Withdraw_RevertsOnInsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert(TokenBank.TokenBank__InsufficientBalance.selector);
        tokenBank.withdraw(1);
    }

    function test_Withdraw_RevertsOnInsufficientBalance_AfterPartialWithdraw() public {
        vm.prank(user);
        tokenBank.deposit(DEPOSIT_AMOUNT);

        vm.prank(user);
        tokenBank.withdraw(WITHDRAW_AMOUNT);

        uint256 remaining = DEPOSIT_AMOUNT - WITHDRAW_AMOUNT;
        vm.prank(user);
        vm.expectRevert(TokenBank.TokenBank__InsufficientBalance.selector);
        tokenBank.withdraw(remaining + 1);
    }
}
