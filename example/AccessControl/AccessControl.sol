// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
访问权限、函数可见性、操作权限等问题
 */
contract AccessControl {
    address owner;
    uint256 interestRate;

    constructor() {
        owner = msg.sender;
    }

    /*/////////////////////////////////////////////
               1、不受限制的初始化函数
    /////////////////////////////////////////////*/

    // 缺乏调用限制，任何人都能改变owner
    function initContract() public {
        owner = msg.sender;
    }

    /*/////////////////////////////////////////////
               2、任何人都能改变owner
    /////////////////////////////////////////////*/
    function changeOwner(address _new) public {
        owner = _new;
    }

    /*/////////////////////////////////////////////
               3、函数可见性使用不当
    /////////////////////////////////////////////*/

    /**
     * 修复方案
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function setInterestRate(uint256 _interestRate) public onlyOwner {
        interestRate = _interestRate;
    }

    /*
    可以用 OpenZeppelin 的 AccessControl 库来精细划分各类角色的权限
    */
}
