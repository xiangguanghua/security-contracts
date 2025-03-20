// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
Unexpected ecrecover Null Address 攻击 是一种利用 Solidity 中 ecrecover 函数返回空地址（address(0)）的漏洞来绕过合约逻辑的攻击方式。
ecrecover 是 Solidity 中的一个内置函数，用于从签名中恢复地址。如果签名无效或格式错误，ecrecover 会返回空地址。如果合约未正确处理这种情况，攻击者可能利用空地址绕过某些限制条件。

攻击原理
ecrecover 函数用于从签名中恢复地址，其签名格式为 (v, r, s)。如果签名无效或格式错误，ecrecover 会返回空地址（address(0)）。如果合约未检查 ecrecover 的返回值，可能会出现以下问题：
1、绕过身份验证：如果合约未检查 ecrecover 返回的地址是否为空，攻击者可以通过构造无效签名，使 ecrecover 返回空地址，从而绕过身份验证。
2、逻辑绕过：如果合约的关键逻辑依赖于 ecrecover 返回的地址，攻击者可以通过构造无效签名，使 ecrecover 返回空地址，从而绕过某些限制条件。
 */

/*
示例 1：未检查 ecrecover 返回地址

问题分析
-如果 ecrecover 返回空地址，authorize 函数可能会错误地认为签名有效，从而绕过身份验证。
-攻击者可以通过构造无效签名，使 ecrecover 返回空地址，从而绕过身份验证。
 */
contract EcrecoverNullAddress {
    function verifySignature(bytes32 hash, uint8 v, bytes32 r, bytes32 s) public pure returns (address) {
        // 未检查 ecrecover 返回的地址是否为空
        address recoveredAddress = ecrecover(hash, v, r, s);
        return recoveredAddress;
    }

    function authorize(bytes32 hash, uint8 v, bytes32 r, bytes32 s) public view returns (bool) {
        address recoveredAddress = verifySignature(hash, v, r, s);
        // 未检查 recoveredAddress 是否为空
        return recoveredAddress == msg.sender;
    }
}

/*
示例 2：依赖 ecrecover 返回地址的逻辑

问题分析
- 如果 ecrecover 返回空地址，transfer 函数可能会错误地认为签名有效，从而导致资金被错误地转移。
- 攻击者可以通过构造无效签名，使 ecrecover 返回空地址，从而绕过签名验证
 */
contract DependentOnEcrecover {
    mapping(address => uint256) public balances;

    function transfer(bytes32 hash, uint8 v, bytes32 r, bytes32 s, uint256 amount) public {
        address recoveredAddress = ecrecover(hash, v, r, s);
        // 未检查 recoveredAddress 是否为空
        require(recoveredAddress == msg.sender, "Invalid signature");
        balances[msg.sender] -= amount;
        balances[recoveredAddress] += amount;
    }
}

/*
解决方法

1. 检查 ecrecover 返回地址
在调用 ecrecover 后，检查返回的地址是否为空。
pragma solidity ^0.8.0;
contract SafeEcrecover {
    function verifySignature(bytes32 hash, uint8 v, bytes32 r, bytes32 s) public pure returns (address) {
        address recoveredAddress = ecrecover(hash, v, r, s);
        require(recoveredAddress != address(0), "Invalid signature");
        return recoveredAddress;
    }

    function authorize(bytes32 hash, uint8 v, bytes32 r, bytes32 s) public pure returns (bool) {
        address recoveredAddress = verifySignature(hash, v, r, s);
        return recoveredAddress == msg.sender;
    }
}

2. 使用 OpenZeppelin 的 ECDSA 库
OpenZeppelin 提供了 ECDSA 库，可以安全地处理签名验证，包括检查空地址。
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
contract UsingECDSA {
    using ECDSA for bytes32;

    function verifySignature(bytes32 hash, bytes memory signature) public pure returns (address) {
        return hash.recover(signature);
    }

    function authorize(bytes32 hash, bytes memory signature) public pure returns (bool) {
        address recoveredAddress = verifySignature(hash, signature);
        return recoveredAddress == msg.sender;
    }
}

3. 验证签名格式
在调用 ecrecover 前，验证签名的格式是否正确。
pragma solidity ^0.8.0;
contract ValidateSignature {
    function verifySignature(bytes32 hash, uint8 v, bytes32 r, bytes32 s) public pure returns (address) {
        require(v == 27 || v == 28, "Invalid signature version");
        address recoveredAddress = ecrecover(hash, v, r, s);
        require(recoveredAddress != address(0), "Invalid signature");
        return recoveredAddress;
    }
}

总结
Unexpected ecrecover Null Address 攻击是一种利用 ecrecover 返回空地址的漏洞来绕过合约逻辑的攻击方式。通过以下方法可以有效避免这种问题：

检查 ecrecover 返回的地址是否为空。
使用 OpenZeppelin 的 ECDSA 库。
验证签名的格式是否正确。
 */
