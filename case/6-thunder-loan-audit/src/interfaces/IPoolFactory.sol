// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

// e get t-swap pool
// q why we need t-swap here
interface IPoolFactory {
    function getPool(address tokenAddress) external view returns (address);
}
