// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20Mock is ERC20, ERC20Permit {
  constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) { }

  /**
   * @notice Gives the caller `amount` in tokens
   */
  function mint(uint256 amount) public {
    _mint(msg.sender, amount);
  }

  function mintTo(uint256 amount, address receiver) public {
    _mint(receiver, amount);
  }
}
