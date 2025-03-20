// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
Lack of Precision 攻击（精度不足攻击）是一种利用数值计算中的精度问题来操纵智能合约行为的攻击方式。
在 Solidity 中，数值计算通常使用整数或定点数（如 uint256），而浮点数不支持。
如果开发者在处理数值时未考虑精度问题，可能会导致资金损失或合约逻辑被绕过。

攻击原理
Solidity 中的数值计算通常是整数运算，除法会截断小数部分。如果开发者未正确处理精度问题，可能会导致以下问题：
1、资金分配不公：例如，在分红或奖励分配时，精度不足可能导致某些用户分到的资金比预期少。
2、逻辑绕过：攻击者可能利用精度问题绕过某些限制条件。
3、累积误差：在多次计算中，精度误差可能累积，导致最终结果与预期严重偏离。
 */

contract DividendDistributor {
    address[] public users;
    mapping(address => uint256) public balances;
    uint256 public totalSupply;

    // 添加用户（仅示例）
    function addUser(address user, uint256 balance) public {
        users.push(user);
        balances[user] = balance;
        totalSupply += balance;
    }

    // 分发分红
    function distributeDividends(uint256 dividends) public {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 userShare = (balances[user] * dividends) / totalSupply;
            payable(user).transfer(userShare);
        }
    }

    // 接收 ETH（用于分红）
    receive() external payable {}
}

/*
问题分析
在 distributeDividends 函数中，userShare 的计算可能由于整数除法截断小数部分，导致某些用户分到的资金比预期少。
如果 balances[user] * dividends < totalSupply，userShare 可能为 0，导致用户无法分到任何资金。

累积精度误差
contract CumulativePrecisionError {
    uint256 public total;

    function add(uint256 amount) public {
        // 假设 amount 是一个很小的值
        total += amount / 1000; // 每次添加 amount / 1000
    }
}
 */

/*
1. 使用更高精度的计算
function distributeDividends() public {
    uint256 dividends = address(this).balance;
    uint256 scale = 1e18; // 放大因子
    for (address user in balances) {
        uint256 userShare = (balances[user] * dividends * scale) / totalSupply;
        payable(user).transfer(userShare / scale);
    }
}

2. 避免整数除法截断
在除法之前，确保被除数足够大，或者使用更复杂的数学库（如 OpenZeppelin 的 SafeMath）。

3. 使用外部库
使用成熟的数学库（如 ABDKMath64x64）来处理高精度计算。

4. 测试边界条件
在测试中覆盖极端情况（如极小值或极大值），确保合约逻辑在精度问题上表现正确。
 */
