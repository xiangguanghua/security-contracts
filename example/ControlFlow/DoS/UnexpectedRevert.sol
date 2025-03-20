// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
DoS with (Unexpected) Revert 攻击（意外回滚导致的拒绝服务攻击）是一种利用合约中的外部调用失败（revert）来阻止正常操作的攻击方式。
攻击者通过构造特定的交易或条件，使合约中的外部调用失败，从而导致整个操作回滚，使合约功能无法正常执行。

攻击原理：
在 Solidity 中，如果合约中的外部调用（如 call、transfer 或 send）失败并触发 revert，整个交易将回滚。攻击者可以利用这一点，通过以下方式实施攻击：
强制外部调用失败：攻击者通过部署恶意合约，使其 fallback 或 receive 函数总是回滚。
依赖外部调用的操作：如果合约的关键操作依赖于外部调用的成功，攻击者可以通过使外部调用失败来阻止这些操作。
 */

/*
示例 1：外部调用失败导致的操作回滚

问题分析
如果 msg.sender 是一个恶意合约，并且其 fallback 或 receive 函数总是回滚，withdraw 函数将无法正常执行。
攻击者可以通过这种方式阻止其他用户提款，导致合约功能被瘫痪。
 */
contract DoSWithRevert {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() public {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance to withdraw");
        // 外部调用可能失败并回滚
        (bool success,) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
        balances[msg.sender] = 0;
    }
}

/*
示例 2：批量操作中的外部调用失败

问题分析
如果 recipients 数组中包含一个恶意合约地址，batchTransfer 函数将因外部调用失败而回滚。
攻击者可以通过向 recipients 数组中添加恶意合约地址，阻止批量转账操作。
 */

contract BatchTransfer {
    function batchTransfer(address[] memory recipients, uint256 amount) public payable {
        for (uint256 i = 0; i < recipients.length; i++) {
            // 外部调用可能失败并回滚
            (bool success,) = recipients[i].call{value: amount}("");
            require(success, "Transfer failed");
        }
    }
}

/*
解决方法

1. 使用 Pull 模式：将资金分配改为 Pull 模式，让用户主动提取资金，而不是合约主动分配。
function withdraw() public {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance to withdraw");
    balances[msg.sender] = 0;
    payable(msg.sender).transfer(balance);
}

2. 避免依赖外部调用的成功：将外部调用与关键操作分离，确保即使外部调用失败，也不会影响合约的其他功能。
function withdraw() public {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance to withdraw");
    balances[msg.sender] = 0;
    // 将资金发送到用户地址，但不依赖其成功
    (bool success, ) = msg.sender.call{value: balance}("");
    if (!success) {
        // 处理失败情况，例如记录日志或退款
        balances[msg.sender] = balance;
    }
}

3. 限制外部调用的目标：避免向未知地址发送资金，或者限制外部调用的目标为可信地址。
function withdraw(address trustedAddress) public {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance to withdraw");
    balances[msg.sender] = 0;
    // 只向可信地址发送资金
    payable(trustedAddress).transfer(balance);
}

4、分批次处理：将批量操作拆分为多个小操作，避免因单个失败导致整个操作回滚。
function batchTransfer(address[] memory recipients, uint256 amount, uint256 start, uint256 end) public payable {
    require(end <= recipients.length, "Invalid range");
    for (uint256 i = start; i < end; i++) {
        (bool success, ) = recipients[i].call{value: amount}("");
        if (!success) {
            // 处理失败情况，例如记录日志或跳过
        }
    }
}

 */

/*
总结
DoS with (Unexpected) Revert 攻击是一种常见的智能合约漏洞，可能导致合约功能被瘫痪或交易失败。通过以下方法可以有效避免这种问题：

使用 Pull 模式代替 Push 模式。
避免依赖外部调用的成功。
限制外部调用的目标为可信地址。
将批量操作拆分为多个小操作。
 */
