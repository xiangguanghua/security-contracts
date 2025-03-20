// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
跨合约重入性是指在智能合约之间发生的重入攻击，这种攻击不仅限于单一合约内部的函数调用，还可能涉及多个合约，尤其是当这些合约共享相同的状态变量时。
在跨合约重入攻击中，如果状态更新不是在外部调用之前完成，那么重入可能导致严重的安全漏洞。

跨合约重入通常发生在多个合约共享同一状态变量，并且其中一些合约在更新这些变量时存在安全隐患。
由于涉及多个合约和共享状态，这种类型的重入问题可能更加复杂且难以发现。
*/

/*/////////////////////////////////////////////
                   被攻击合约 
/////////////////////////////////////////////*/
contract Bank {
    // 共享状态变量
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(address to, uint256 amount) public {
        require(balances[to] >= amount, "Insufficient funds");
        (bool success,) = to.call{value: amount}("");
        require(success, "Transfer failed");
        balances[to] -= amount;
    }
}

/*/////////////////////////////////////////////
                   被攻击合约 
/////////////////////////////////////////////*/
contract Trader {
    Bank bank;

    constructor(address _bank) {
        bank = Bank(_bank);
    }

    function exploitWithdrawal(address to) public {
        bank.withdraw(to, 100);
    }
}

/*/////////////////////////////////////////////
                   攻击合约 
/////////////////////////////////////////////*/
contract Attack {
    Bank bank;
    Trader trader;

    constructor(address _bank, address _trader) {
        bank = Bank(_bank);
        trader = Trader(_trader);
    }

    function attack(address to) public payable {
        bank.deposit{value: msg.value}();
        trader.exploitWithdrawal(to);
    }
}
