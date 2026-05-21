# Foundry Test Bank

Foundry 项目，包含 **Bank** 和 **TokenBank** 两个智能合约及其完整测试套件。

## 合约说明

### Bank

一个简单的 ETH 存款银行合约：

- 用户可存入 ETH，合约记录每位用户的存款额
- 实时维护存款金额前 3 名的排行榜
- 仅管理员可提取合约中的 ETH

### TokenBank

一个基于 ERC20 的代币银行合约：

- 支持任意 ERC20 代币的存取
- 使用 low-level call 兼容 USDT 等非标准 ERC20（不返回 bool）
- 支持部分提取和全部提取

## 测试说明

### Bank 测试（`test/Bank.t.sol`）

| 测试分类 | 测试用例 | 说明 |
|---------|---------|------|
| 存款余额 | `test_Deposit_BalanceUpdated` | 单次和多次存款后余额正确更新 |
| | `test_Deposit_ContractBalanceUpdated` | 合约 ETH 余额正确累加 |
| | `test_Deposit_EmitsEvent` | 存款事件正确触发 |
| | `test_Receive_FallbackFunctionsAsDeposit` | receive 回退函数等价于 deposit |
| | `test_RevertOn_ZeroDeposit` | 0 金额存款被拒绝 |
| Top 3 | `test_TopDepositors_OneUser` | 1 个用户时排行榜仅含该用户 |
| | `test_TopDepositors_TwoUsers` | 2 个用户按余额排序 |
| | `test_TopDepositors_ThreeUsers` | 3 个用户按余额排序 |
| | `test_TopDepositors_FourUsers` | 4 个用户时仅显示前 3 名 |
| | `test_TopDepositors_SameUserMultipleDeposits` | 同一用户多次存款后排名更新 |
| 权限 | `test_Withdraw_AdminCanWithdraw` | 管理员可成功提款 |
| | `test_Withdraw_NonAdminReverts` | 非管理员提款被拒绝 |
| | `test_Withdraw_NonAdminCannotWithdrawEvenIfDepositor` | 存款人非管理员也不能提款 |
| 边界 | `test_Withdraw_RevertsOnZeroAmount` | 0 金额提款被拒绝 |
| | `test_Withdraw_RevertsOnInsufficientBalance` | 超额提款被拒绝 |
| | `test_Withdraw_EmitsEvent` | 提款事件正确触发 |

### TokenBank 测试（`test/TokenBank.t.sol`）

TokenBank 测试使用以太坊主网 Fork 模式，验证对 USDT 代币的存取操作。

| 测试分类 | 测试用例 | 说明 |
|---------|---------|------|
| 存款 | `test_Deposit_USDT` | USDT 存款后银行余额、用户余额、代币转移均正确 |
| | `test_Deposit_EmitsEvent` | 存款事件正确触发 |
| | `test_Deposit_MultipleUsers` | 多用户存款互不影响 |
| | `test_Deposit_RevertsOnZero` | 0 金额存款被拒绝 |
| 取款 | `test_Withdraw_Partial` | 部分取款后余额正确 |
| | `test_Withdraw_All` | 全部取款后余额归零 |
| | `test_Withdraw_EmitsEvent` | 取款事件正确触发 |
| | `test_Withdraw_RevertsOnZero` | 0 金额取款被拒绝 |
| | `test_Withdraw_RevertsOnInsufficientBalance` | 超额取款被拒绝 |
| | `test_Withdraw_RevertsOnInsufficientBalance_AfterPartialWithdraw` | 部分取款后超额取款被拒绝 |

## 前置条件

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- 以太坊主网 RPC URL（用于 Fork 测试），可使用免费公共 RPC 或 Infura/Alchemy 等

## 安装与运行

```shell
# 安装依赖
forge install

# 编译合约
forge build

# 运行所有测试
forge test -vvv

# 仅运行 Bank 测试（无需 RPC）
forge test --match-contract BankTest -vvv

# 仅运行 TokenBank 测试（需要 RPC）
forge test --match-contract TokenBankTest -vvv
```

## RPC 配置

在 `foundry.toml` 中配置以太坊主网 RPC：

```toml
[rpc_endpoints]
mainnet = "https://ethereum-rpc.publicnode.com"
```

也可通过环境变量指定：

```shell
export ETH_RPC_URL="你的RPC地址"
```

## 测试结果

最近一次完整测试结果（28 个测试全部通过）：

```
Ran 16 tests for test/Bank.t.sol:BankTest
[PASS] test_Deposit_BalanceUpdated()
[PASS] test_Deposit_ContractBalanceUpdated()
[PASS] test_Deposit_EmitsEvent()
[PASS] test_Receive_FallbackFunctionsAsDeposit()
[PASS] test_RevertOn_ZeroDeposit()
[PASS] test_TopDepositors_FourUsers()
[PASS] test_TopDepositors_OneUser()
[PASS] test_TopDepositors_SameUserMultipleDeposits()
[PASS] test_TopDepositors_ThreeUsers()
[PASS] test_TopDepositors_TwoUsers()
[PASS] test_Withdraw_AdminCanWithdraw()
[PASS] test_Withdraw_EmitsEvent()
[PASS] test_Withdraw_NonAdminCannotWithdrawEvenIfDepositor()
[PASS] test_Withdraw_NonAdminReverts()
[PASS] test_Withdraw_RevertsOnInsufficientBalance()
[PASS] test_Withdraw_RevertsOnZeroAmount()

Ran 10 tests for test/TokenBank.t.sol:TokenBankTest
[PASS] test_Deposit_EmitsEvent()
[PASS] test_Deposit_MultipleUsers()
[PASS] test_Deposit_RevertsOnZero()
[PASS] test_Deposit_USDT()
[PASS] test_Withdraw_All()
[PASS] test_Withdraw_EmitsEvent()
[PASS] test_Withdraw_Partial()
[PASS] test_Withdraw_RevertsOnInsufficientBalance()
[PASS] test_Withdraw_RevertsOnInsufficientBalance_AfterPartialWithdraw()
[PASS] test_Withdraw_RevertsOnZero()

Suite result: ok. 28 passed; 0 failed; 0 skipped
```
