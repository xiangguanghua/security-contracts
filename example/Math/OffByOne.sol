// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
Off-By-One 攻击：
Off-By-One 攻击通常与数组或循环的边界处理不当有关。
由于 Solidity 是智能合约编程语言，这种错误可能导致严重的后果，例如资金损失或合约被恶意利用。
*/

contract OffByOneExample {
    uint256[] public balances;

    function addBalance(uint256 amount) public {
        balances.push(amount);
    }

    function distributeRewards() public {
        // Off-By-One 错误：i <= balances.length 导致越界访问
        for (uint256 i = 0; i <= balances.length; i++) {
            balances[i] += 1; // 当 i == balances.length 时，访问越界
        }
    }
}

/*
修复循环条件：将循环条件改为 i < balances.length，确保不会越界访问。
  function distributeRewards() public {
      for (uint256 i = 0; i < balances.length; i++) {
         balances[i] += 1;
      }
  }

Off-By-One 错误可能导致合约异常或安全漏洞。通过以下方法可以避免这种问题：
-确保循环条件正确（i < length 而不是 i <= length）。
-使用 Solidity 0.8.0 及以上版本，利用内置的边界检查功能。
-在关键操作前显式检查数组边界。

 */
