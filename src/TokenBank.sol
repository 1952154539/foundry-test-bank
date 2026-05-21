// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenBank {
    IERC20 public immutable token;
    mapping(address => uint256) public balances;
    uint256 public totalDeposits;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    error TokenBank__ZeroAddress();
    error TokenBank__ZeroAmount();
    error TokenBank__InsufficientBalance();
    error TokenBank__TransferFailed();

    constructor(address _token) {
        if (_token == address(0)) revert TokenBank__ZeroAddress();
        token = IERC20(_token);
    }

    /// @notice Deposit tokens into the bank.
    /// @dev Uses low-level call for compatibility with tokens that don't return bool (e.g. USDT).
    /// @param amount Amount of tokens to deposit.
    function deposit(uint256 amount) external {
        if (amount == 0) revert TokenBank__ZeroAmount();
        _safeTransferFrom(token, msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        totalDeposits += amount;
        emit Deposited(msg.sender, amount);
    }

    /// @notice Withdraw a specific amount of previously deposited tokens.
    /// @param amount Amount of tokens to withdraw.
    function withdraw(uint256 amount) external {
        if (amount == 0) revert TokenBank__ZeroAmount();
        if (balances[msg.sender] < amount) revert TokenBank__InsufficientBalance();

        balances[msg.sender] -= amount;
        totalDeposits -= amount;
        _safeTransfer(token, msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Withdraw all deposited tokens.
    function withdrawAll() external {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert TokenBank__InsufficientBalance();

        balances[msg.sender] = 0;
        totalDeposits -= amount;
        _safeTransfer(token, msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Reject direct ETH transfers.
    receive() external payable {
        revert TokenBank__TransferFailed();
    }

    // ══════════════════════════════════════════════
    //  Internal: safe transfer wrappers
    // ══════════════════════════════════════════════

    function _safeTransferFrom(IERC20 token_, address from, address to, uint256 amount) private {
        (bool success, bytes memory data) = address(token_).call(
            abi.encodeCall(IERC20.transferFrom, (from, to, amount))
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool))))
            revert TokenBank__TransferFailed();
    }

    function _safeTransfer(IERC20 token_, address to, uint256 amount) private {
        (bool success, bytes memory data) = address(token_).call(
            abi.encodeCall(IERC20.transfer, (to, amount))
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool))))
            revert TokenBank__TransferFailed();
    }
}
