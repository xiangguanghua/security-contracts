// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
/*
在实现 ERC20 标准的过程中，approve 函数的一些误用可能导致严重的安全漏洞，被称为 ApproveScam.

ApproveScam 漏洞源于 ERC20 标准中 approve 函数的误用。approve 函数本身的设计目的是允许代币持有者授权某个地址可以从持有者账户中转移一定数量的代币。
但如果持有者授权的金额过大(通常是无限大type(uint256).max)，攻击者就可以在未经持有者同意的情况下，从持有者账户中转移走所有代币。
具体来说，一旦 Alice 授权了 Eve 可以无限转移 Alice 账户中的代币，Eve 就可以调用 transferFrom 函数，将 Alice 账户中的所有代币转移到自己的账户中。这就是 ApproveScam 漏洞的核心原理。

// Alice 授权 Eve 可以无限转移自己账户中的代币
ERC20Contract.approve(address(eve), type(uint256).max);

// Eve 利用授权转移 Alice 账户中的所有代币
ERC20Contract.transferFrom(address(alice), address(eve), 1000);
 */

/*/////////////////////////////////////////////
                   被攻击合约 
/////////////////////////////////////////////*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    constructor() ERC20("MyToken", "MTK") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function approve(address spender, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }
}
