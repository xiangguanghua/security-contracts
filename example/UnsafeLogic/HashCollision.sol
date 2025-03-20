// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
Hash Collision when using abi.encodePacked() with Multiple Variable-Length Arguments 攻击
在 Solidity 中，abi.encodePacked() 是一种将多个参数紧密打包为字节数组的方法。
然而，当使用 abi.encodePacked() 处理多个可变长度参数（如 string、bytes 或动态数组）时，可能会出现哈希碰撞（Hash Collision）问题。
这种问题可能导致安全漏洞，攻击者可以构造不同的输入来生成相同的哈希值，从而破坏合约的逻辑。
 */

/*
1. 问题描述
abi.encodePacked() 不会在参数之间添加分隔符，而是直接将参数紧密拼接在一起。当处理多个可变长度参数时，不同的输入可能会生成相同的字节序列，从而导致哈希碰撞。

示例：
function hashInput(string memory a, string memory b) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(a, b));
}
对于以下输入：

a = "abc", b = "def" → abi.encodePacked("abc", "def") → "abcdef"
a = "ab", b = "cdef" → abi.encodePacked("ab", "cdef") → "abcdef"
尽管输入不同，但生成的字节序列相同，导致哈希值相同。
 */

/*
2. 攻击方式
攻击者可以通过构造不同的输入来生成相同的哈希值，从而绕过合约的逻辑或获取不正当的利益。

示例场景：
假设一个合约使用 abi.encodePacked() 来生成哈希值，用于验证用户提交的数据：

function verifyData(string memory data1, string memory data2, bytes32 expectedHash) public pure returns (bool) {
    bytes32 computedHash = keccak256(abi.encodePacked(data1, data2));
    return computedHash == expectedHash;
}
攻击者可以构造以下输入：

data1 = "hello", data2 = "world" → 哈希值为 H1
data1 = "hellow", data2 = "orld" → 哈希值也为 H1
如果合约依赖哈希值来验证数据的唯一性，攻击者可以通过提交不同的输入来绕过验证。
 */

/*
3. 防御措施
为了避免哈希碰撞问题，可以采取以下措施：

1. 使用 abi.encode() 代替 abi.encodePacked()
abi.encode() 会在参数之间添加分隔符，从而避免不同输入生成相同的字节序列。

function hashInput(string memory a, string memory b) public pure returns (bytes32) {
    return keccak256(abi.encode(a, b));
}
2. 显式添加分隔符
在 abi.encodePacked() 中手动添加分隔符（如长度信息或固定分隔符）来区分参数。

function hashInput(string memory a, string memory b) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(a.length, a, b.length, b));
}
3. 使用固定长度参数
如果可能，尽量使用固定长度参数（如 bytes32 或 uint256），避免使用可变长度参数。

4. 引入唯一标识符
在哈希计算中引入唯一标识符（如 msg.sender 或 block.timestamp），以增加输入的唯一性。

function hashInput(string memory a, string memory b) public view returns (bytes32) {
    return keccak256(abi.encodePacked(a, b, msg.sender));
}
5. 使用链外哈希计算
在链外计算哈希值并提交到合约，确保输入的唯一性和安全性。

4. 总结
使用 abi.encodePacked() 处理多个可变长度参数时，可能会因缺少分隔符而导致哈希碰撞问题。攻击者可以通过构造不同的输入来生成相同的哈希值，从而破坏合约的逻辑。为了避免此类问题，开发者应使用 abi.encode()、显式添加分隔符或引入唯一标识符来确保哈希值的唯一性和安全性。
 */
