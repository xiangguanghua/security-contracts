// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
Unchecked Return Values 攻击 是一种由于未检查外部调用返回值而导致的智能合约漏洞。
在 Solidity 中，外部调用（如 call、send 或 transfer）可能会失败并返回 false，但如果没有检查返回值，合约可能会继续执行，导致资金损失或状态不一致。

攻击原理：
在 Solidity 中，外部调用（如 call、send 或 transfer）的返回值表示调用是否成功。如果未检查返回值，可能会出现以下问题：
1、资金损失：如果外部调用失败，但合约未检查返回值，资金可能会被锁定或丢失。
2、状态不一致：如果外部调用失败，但合约继续执行，可能会导致状态更新与实际操作不一致。
 */

/*
示例 1：未检查 send 返回值
问题分析：
如果 send 失败（例如接收方是合约且 fallback 函数回滚），success 将为 false，但状态仍会被更新。
这会导致用户余额被清零，但资金未成功发送，造成资金损失。
 */
contract UncheckedSend {
    mapping(address => uint256) public balances;

    function withdraw() public {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance to withdraw");
        // 未检查 send 的返回值
        // bool success = payable(msg.sender).send(balance);
        // 无论 send 是否成功，都会更新状态
        balances[msg.sender] = 0;
    }
}

/*
示例 2：未检查 call 返回值
问题分析：
如果 call 失败（例如接收方是合约且 fallback 函数回滚），success 将为 false，但状态仍会被更新。
这会导致用户余额被清零，但资金未成功发送，造成资金损失。
 */
contract UncheckedCall {
    mapping(address => uint256) public balances;

    function withdraw() public {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance to withdraw");
        // 未检查 call 的返回值
        // (bool success,) = msg.sender.call{value: balance}("");
        // 无论 call 是否成功，都会更新状态
        balances[msg.sender] = 0;
    }
}

/*
解决方法
1. 检查外部调用的返回值
在外部调用后，检查返回值并根据结果决定是否继续执行。
function withdraw() public {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance to withdraw");
    // 检查 send 的返回值
    bool success = payable(msg.sender).send(balance);
    require(success, "Transfer failed");
    balances[msg.sender] = 0;
}

2. 使用 transfer 代替 send
transfer 在失败时会自动回滚，无需手动检查返回值。
function withdraw() public {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance to withdraw");
    // 使用 transfer，失败时会自动回滚
    payable(msg.sender).transfer(balance);
    balances[msg.sender] = 0;
}

3. 使用 call 并检查返回值
call 提供了更大的灵活性，但需要手动检查返回值。
function withdraw() public {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance to withdraw");
    // 检查 call 的返回值
    (bool success, ) = msg.sender.call{value: balance}("");
    require(success, "Transfer failed");
    balances[msg.sender] = 0;
}

4. 使用 Pull 模式
将资金分配改为 Pull 模式，让用户主动提取资金，而不是合约主动分配。
function withdraw() public {
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance to withdraw");
    balances[msg.sender] = 0;
    payable(msg.sender).transfer(balance);
}

总结：Unchecked Return Values 攻击是一种常见的智能合约漏洞，可能导致资金损失或状态不一致。通过以下方法可以有效避免这种问题：

检查外部调用的返回值。
1、使用 transfer 代替 send。
2、使用 call 并检查返回值。
3、使用 Pull 模式代替 Push 模式。
 */
