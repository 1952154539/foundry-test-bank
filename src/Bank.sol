// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Bank
 * @notice A simple bank contract supporting deposits and admin withdrawals.
 * @dev Tracks the top 3 depositors by balance.
 */
contract Bank {
    address public immutable admin;

    /// @notice Mapping from user address to deposited balance.
    mapping(address => uint256) public balances;

    /// @notice Top 3 depositors sorted by balance descending.
    address[3] public topDepositors;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed admin, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Bank: caller is not the admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    /// @notice Accept ETH sent directly to the contract address.
    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    /// @notice Deposit ETH into the bank.
    function deposit() external payable {
        _deposit(msg.sender, msg.value);
    }

    /// @dev Internal deposit logic. Updates balance and leaderboard.
    function _deposit(address user, uint256 amount) private {
        require(amount > 0, "Bank: amount must be greater than zero");
        balances[user] += amount;
        _updateTopDepositors(user);
        emit Deposited(user, amount);
    }

    /// @notice Admin-only: withdraw ETH from the contract.
    /// @param amount The amount of wei to withdraw.
    function withdraw(uint256 amount) external onlyAdmin {
        require(amount > 0, "Bank: amount must be greater than zero");
        require(address(this).balance >= amount, "Bank: insufficient contract balance");
        payable(admin).transfer(amount);
        emit Withdrawn(admin, amount);
    }

    /// @notice Returns the total ETH balance held by the contract.
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Returns the top 3 depositor addresses.
    function getTopDepositors() external view returns (address[3] memory) {
        return topDepositors;
    }

    // ── Internal: maintain top 3 leaderboard ──────────────────────────────

    /// @dev Rebuild the top 3 after a deposit.  Gathers the existing top-3
    ///      (minus the depositor's old slot, if any) plus the depositor,
    ///      sorts descending by balance, and keeps the top 3.
    function _updateTopDepositors(address user) private {
        uint256 userBalance = balances[user];

        // Locate depositor's current position, if any.
        int256 found = -1;
        for (uint256 i = 0; i < 3; i++) {
            if (topDepositors[i] == user) {
                found = int256(i);
                break;
            }
        }

        // Gather candidates (max 4: up to 3 existing + the depositor).
        address[4] memory candidates;
        uint256[4] memory candidateBals;
        uint256 count;

        for (uint256 i = 0; i < 3; i++) {
            address addr = topDepositors[i];
            if (addr == address(0)) break;          // no more entries
            if (found >= 0 && addr == user) continue; // skip old slot
            candidates[count]   = addr;
            candidateBals[count] = balances[addr];
            count++;
        }

        // Always add depositor with their updated balance.
        candidates[count]   = user;
        candidateBals[count] = userBalance;
        count++;

        // Simple bubble sort (descending by balance).
        for (uint256 i = 0; i < count; i++) {
            for (uint256 j = 0; j < count - 1 - i; j++) {
                if (candidateBals[j] < candidateBals[j + 1]) {
                    (candidateBals[j], candidateBals[j + 1]) = (candidateBals[j + 1], candidateBals[j]);
                    (candidates[j], candidates[j + 1])       = (candidates[j + 1], candidates[j]);
                }
            }
        }

        // Write back top 3.
        for (uint256 i = 0; i < 3; i++) {
            topDepositors[i] = i < count ? candidates[i] : address(0);
        }
    }
}
