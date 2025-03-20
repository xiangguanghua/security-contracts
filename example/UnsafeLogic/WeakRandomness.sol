// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
Weak Sources of Randomness from Chain Attributes 攻击：
在区块链和智能合约中，随机数的生成是一个关键且复杂的问题。如果随机数的来源不够安全或可预测，可能会导致严重的安全漏洞，使得攻击者能够利用这些漏洞进行攻击。

1. 使用区块属性作为随机源
- 问题：许多智能合约使用区块属性（如 block.timestamp, blockhash, block.number）作为随机数的来源。这些属性是可预测的，因为区块信息是公开的，攻击者可以提前计算或预测这些值。

攻击方式：
-时间戳预测：block.timestamp 是矿工可以轻微操纵的，攻击者可以通过调整交易时间或与矿工合谋来影响结果。
-区块哈希预测：blockhash 是已知的，攻击者可以通过提前计算或与矿工合谋来操纵结果。

示例：
uint256 random = uint256(blockhash(block.number - 1)) % 100;
攻击者可以通过预测前一个区块的哈希值来操纵随机数。


2. 使用链上公开数据
问题：使用链上公开数据（如合约余额、交易历史）作为随机源。这些数据虽然是公开的，但攻击者可以通过精心设计的交易来影响这些数据。

攻击方式：
-合约余额操纵：攻击者可以通过向合约发送或提取资金来影响合约余额，从而操纵随机数。
-交易历史分析：攻击者可以通过分析交易历史来预测随机数的生成逻辑。

示例：
uint256 random = address(this).balance % 100;
攻击者可以通过向合约发送特定数量的资金来操纵随机数。

3. 使用链外数据（Oracle）
问题：虽然链外数据（如通过 Oracle 获取的随机数）可以增加随机性，但如果 Oracle 的实现不安全，仍然可能被攻击。

攻击方式：
- Oracle 操纵：攻击者可以攻击 Oracle 的源数据或与 Oracle 提供者合谋来操纵随机数。
- 延迟攻击：攻击者可以通过延迟 Oracle 的响应来影响随机数的生成。

示例：
uint256 random = oracle.getRandomNumber();
如果 Oracle 的实现不安全，攻击者可以操纵随机数的生成。


4. 使用可预测的用户输入
问题：如果随机数的生成依赖于用户输入（如 msg.sender 或交易数据），攻击者可以通过精心设计的输入来操纵随机数。

攻击方式：
- 地址操纵：攻击者可以通过创建多个地址来影响随机数的生成。
- 交易数据操纵：攻击者可以通过发送特定交易数据来影响随机数。

示例：
uint256 random = uint256(msg.sender) % 100;
攻击者可以通过选择特定的地址来操纵随机数。
 */

/*
防御措施
1、使用安全的随机源：
- 使用链外随机数生成器（如 Chainlink VRF）来获取安全的随机数。
- 避免使用区块属性或链上公开数据作为随机源。

2、引入延迟和不可预测性：
- 在随机数生成过程中引入延迟（如使用多个区块的哈希值）以增加不可预测性。

3、多方参与：
- 使用多方计算（MPC）或提交-揭示（commit-reveal）机制来生成随机数，确保没有单一方能够操纵结果。

4、审计和测试：
- 对智能合约进行严格的安全审计和测试，确保随机数生成逻辑的安全性。
 */

/*
弱随机性来源是智能合约中常见的安全漏洞，攻击者可以通过预测或操纵随机数来获得不正当的利益。开发者应避免使用可预测的随机源，并采用安全的随机数生成机制来保护合约的安全性。
 */

contract GuessTheRandomNumber {
    constructor() payable {}

    function guess(uint256 _guess) public {
        uint256 answer = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)));

        if (_guess == answer) {
            (bool sent,) = msg.sender.call{value: 1 ether}("");
            require(sent, "Failed to send Ether");
        }
    }
}

contract Attack {
    receive() external payable {}

    function attack(GuessTheRandomNumber guessTheRandomNumber) public {
        uint256 answer = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)));

        guessTheRandomNumber.guess(uint8(answer));
    }

    // Helper function to check balance
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
