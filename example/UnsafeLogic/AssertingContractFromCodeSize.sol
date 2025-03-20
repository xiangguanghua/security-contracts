// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
1. 问题描述
在 Solidity 中，extcodesize 操作码用于获取目标地址的代码大小。开发者通常使用此操作码来判断目标地址是否为合约地址（代码大小 > 0）或外部账户（代码大小 = 0）。然而，这种检查在某些情况下并不可靠，尤其是在合约构造函数（constructor）中，因为此时合约的代码尚未部署，extcodesize 返回 0。

常见使用场景：
限制某些功能仅允许外部账户调用。
防止合约地址参与某些操作（如空投、奖励分配）。
主要风险：
构造函数绕过：在合约构造函数中，extcodesize 返回 0，攻击者可以在构造函数中调用目标函数。
预编译合约：某些预编译合约（如 ecrecover）的代码大小为 0，可能被误判为外部账户。
2. 攻击方式
1. 构造函数绕过
攻击者可以在合约的构造函数中调用目标函数，因为此时合约的代码尚未部署，extcodesize 返回 0。

示例：

contract Vulnerable {
    function isContract(address addr) public view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function restrictedFunction() public {
        require(!isContract(msg.sender), "Contracts not allowed");
        // 执行受限功能
    }
}

contract Attacker {
    constructor(address target) {
        Vulnerable(target).restrictedFunction();
    }
}
攻击者部署 Attacker 合约时，在构造函数中调用 restrictedFunction，此时 extcodesize 返回 0，绕过检查。

2. 预编译合约绕过
某些预编译合约（如 ecrecover）的代码大小为 0，可能被误判为外部账户。

示例：

contract Vulnerable {
    function isContract(address addr) public view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function restrictedFunction() public {
        require(!isContract(msg.sender), "Contracts not allowed");
        // 执行受限功能
    }
}

contract Attacker {
    function attack(address target) public {
        Vulnerable(target).restrictedFunction();
    }
}
攻击者调用 attack 函数时，传入预编译合约地址（如 ecrecover），绕过检查。

3. 防御措施
1. 使用 tx.origin 检查
使用 tx.origin 来确保调用者必须是外部账户（EOA），而不是合约。

改进示例：

function restrictedFunction() public {
    require(msg.sender == tx.origin, "Contracts not allowed");
    // 执行受限功能
}
2. 避免依赖 extcodesize
避免使用 extcodesize 来判断目标地址是否为合约，尤其是在构造函数中。

改进示例：

function isContract(address addr) public view returns (bool) {
    uint256 size;
    assembly {
        size := extcodesize(addr)
    }
    return size > 0 && addr != address(0);
}
3. 引入延迟检查
在构造函数中引入延迟检查，确保合约代码已部署。

改进示例：

contract Vulnerable {
    mapping(address => bool) private _initialized;

    function restrictedFunction() public {
        require(!isContract(msg.sender) || _initialized[msg.sender], "Contracts not allowed");
        // 执行受限功能
        _initialized[msg.sender] = true;
    }
}
4. 使用高级别检查
使用高级别检查（如 isContract 库）来判断目标地址是否为合约。

改进示例：

import "@openzeppelin/contracts/utils/Address.sol";

contract Vulnerable {
    using Address for address;

    function restrictedFunction() public {
        require(!msg.sender.isContract(), "Contracts not allowed");
        // 执行受限功能
    }
}
4. 总结
Asserting Contract from Code Size 攻击利用了 extcodesize 操作码的局限性，攻击者可以通过构造函数或预编译合约绕过检查。为了防御此类攻击，开发者应避免依赖 extcodesize，使用 tx.origin 检查，引入延迟检查，或使用高级别检查库。通过这些措施，可以确保合约能够正确区分外部账户和合约地址，防止安全漏洞。
 */
