// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
  Signature Replay Attacks（签名重放攻击） 是一种攻击方式，攻击者通过重复使用有效的签名来多次执行某个操作，
  从而绕过合约的安全检查。这种攻击通常发生在合约没有正确防止签名被重用的场景中。

  1. 签名重放攻击的原理
签名重放攻击的核心问题在于，合约没有确保每个签名只能使用一次。攻击者可以通过以下步骤实施攻击：

用户生成一个有效的签名，用于执行某个操作（例如转账）。
攻击者截获该签名，并重复使用它来执行相同的操作。
由于合约没有检查签名是否已被使用，攻击者可以多次执行操作，导致合约状态被意外修改。
 */

/*/////////////////////////////////////////////
                   被攻击合约 
/////////////////////////////////////////////*/
contract ReplayAttackVulnerable {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    /*
    该合约允许用户通过签名来执行转账操作。
    合约验证签名的有效性，但没有检查签名是否已被使用。
    攻击者可以截获签名并重复使用，导致多次转账
    */
    function transfer(address to, uint256 amount, bytes32 message, uint8 v, bytes32 r, bytes32 s) public {
        // 验证签名
        address signer = ecrecover(message, v, r, s);
        require(signer == msg.sender, "Invalid signature");

        // 转账
        require(balances[signer] >= amount, "Insufficient balance");
        balances[signer] -= amount;
        balances[to] += amount;
    }
}

/*/////////////////////////////////////////////
                   攻击合约 
/////////////////////////////////////////////*/
interface IReplayAttackVulnerable {
    function transfer(address to, uint256 amount, bytes32 message, uint8 v, bytes32 r, bytes32 s) external;
}

contract ReplayAttack {
    address public target; // 目标合约地址
    address public attacker; // 攻击者地址

    constructor(address _target) {
        target = _target;
        attacker = msg.sender;
    }

    function attack(address to, uint256 amount, bytes32 message, uint8 v, bytes32 r, bytes32 s) public {
        // 重复调用目标合约的 transfer 函数
        IReplayAttackVulnerable(target).transfer(to, amount, message, v, r, s);
    }
}

/*
 修复方法
为了防止签名重放攻击，合约需要确保每个签名只能使用一次。以下是修复方法
方法 1：使用 Nonce 机制
为每个签名添加一个唯一的 nonce 值，并在合约中记录已使用的 nonce 值。
pragma solidity ^0.8.0;

contract ReplayAttackFixed {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public nonces;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function transfer(address to, uint256 amount, uint256 nonce, bytes32 message, uint8 v, bytes32 r, bytes32 s) public {
        // 验证签名
        address signer = ecrecover(message, v, r, s);
        require(signer == msg.sender, "Invalid signature");

        // 检查 nonce 是否已被使用
        require(nonce == nonces[signer], "Invalid nonce");
        nonces[signer]++;

        // 转账
        require(balances[signer] >= amount, "Insufficient balance");
        balances[signer] -= amount;
        balances[to] += amount;
    }
}


方法 2：结合消息哈希
在验证签名时，结合消息和签名一起哈希，并记录已使用的哈希值
pragma solidity ^0.8.0;

contract ReplayAttackFixed {
    mapping(address => uint256) public balances;
    mapping(bytes32 => bool) public usedSignatures;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function transfer(address to, uint256 amount, bytes32 message, uint8 v, bytes32 r, bytes32 s) public {
        // 验证签名
        address signer = ecrecover(message, v, r, s);
        require(signer == msg.sender, "Invalid signature");

        // 检查签名是否已被使用
        bytes32 signatureHash = keccak256(abi.encodePacked(message, v, r, s));
        require(!usedSignatures[signatureHash], "Signature already used");
        usedSignatures[signatureHash] = true;

        // 转账
        require(balances[signer] >= amount, "Insufficient balance");
        balances[signer] -= amount;
        balances[to] += amount;
    }
}
 */
