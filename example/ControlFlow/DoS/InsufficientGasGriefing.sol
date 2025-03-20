// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
Insufficient Gas Griefing 攻击 是一种利用合约中外部调用 Gas 不足而导致操作失败的攻击方式。
攻击者通过构造特定的交易或条件，使合约中的外部调用因 Gas 不足而失败，从而导致整个操作回滚或合约功能被瘫痪。

攻击原理：
在 Solidity 中，合约可以通过 call、transfer 或 send 向外部地址发送以太币或调用外部合约。这些操作需要消耗一定的 Gas。
如果 Gas 不足，外部调用将失败并触发 revert，导致整个操作回滚。

攻击者可以利用这一点，通过以下方式实施攻击：
强制外部调用失败：攻击者通过部署恶意合约，使其 fallback 或 receive 函数消耗大量 Gas，导致外部调用失败。
依赖外部调用的操作：如果合约的关键操作依赖于外部调用的成功，攻击者可以通过使外部调用失败来阻止这些操作。
 */

/*
示例 1：外部调用 Gas 不足导致的操作回滚

问题分析：
如果 msg.sender 是一个恶意合约，并且其 fallback 或 receive 函数消耗大量 Gas，withdraw 函数将因 Gas 不足而失败。
攻击者可以通过这种方式阻止其他用户提款，导致合约功能被瘫痪。
 */
contract InsufficientGasGriefing {
    mapping(address => uint256) public balances;

    function withdraw() public {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance to withdraw");
        // 外部调用可能因 Gas 不足而失败
        (bool success,) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
        balances[msg.sender] = 0;
    }
}

/*
解决方法：
1. 使用 Pull 模式
将资金分配改为 Pull 模式，让用户主动提取资金，而不是合约主动分配。
function withdraw() public {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance to withdraw");
    balances[msg.sender] = 0;
    payable(msg.sender).transfer(balance);
}

2. 避免依赖外部调用的成功
将外部调用与关键操作分离，确保即使外部调用失败，也不会影响合约的其他功能。
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

3. 限制外部调用的目标
避免向未知地址发送资金，或者限制外部调用的目标为可信地址。
function withdraw(address trustedAddress) public {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance to withdraw");
    balances[msg.sender] = 0;
    // 只向可信地址发送资金
    payable(trustedAddress).transfer(balance);
}

4. 分批次处理
将批量操作拆分为多个小操作，避免因单个失败导致整个操作回滚。
function batchTransfer(address[] memory recipients, uint256 amount, uint256 start, uint256 end) public payable {
    require(end <= recipients.length, "Invalid range");
    for (uint256 i = start; i < end; i++) {
        (bool success, ) = recipients[i].call{value: amount}("");
        if (!success) {
            // 处理失败情况，例如记录日志或跳过
        }
    }
}

总结：
Insufficient Gas Griefing 攻击是一种常见的智能合约漏洞，可能导致合约功能被瘫痪或交易失败。通过以下方法可以有效避免这种问题：

使用 Pull 模式代替 Push 模式。
1、避免依赖外部调用的成功。
2、限制外部调用的目标为可信地址。
3、将批量操作拆分为多个小操作。
 */
