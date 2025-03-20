// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
Unsupported Opcodes 攻击 是指攻击者利用某些以太坊虚拟机（EVM）操作码（opcodes）在不同环境或版本中的不兼容性，导致智能合约无法正常执行或产生意外行为。
这种攻击通常发生在合约部署或升级时，尤其是在分叉链、测试网或特定硬分叉环境中。
 */

/*
1. 问题描述
EVM 支持一系列操作码，用于执行合约的逻辑。然而，某些操作码可能在不同环境或以太坊版本中不被支持。如果合约使用了这些不支持的操作码，可能会导致以下问题：

合约无法部署。
合约执行失败，抛出异常。
合约行为与预期不符。
常见的不支持操作码：
SELFDESTRUCT：在某些分叉链或测试网中可能被禁用。
CALLCODE：已被弃用，推荐使用 DELEGATECALL。
CREATE2：在较旧的以太坊版本中不支持。
CHAINID 和 SELFBALANCE：在较旧的以太坊版本中不支持。
2. 攻击方式
1. 部署失败
如果合约使用了目标环境中不支持的操作码，部署过程可能会失败。

示例：

contract SelfDestructible {
    function destroy() public {
        selfdestruct(payable(msg.sender));
    }
}
在禁用 SELFDESTRUCT 的链上，此合约无法部署。

2. 执行失败
如果合约在执行过程中使用了不支持的操作码，交易会抛出异常。

示例：

contract ChainIdChecker {
    function getChainId() public pure returns (uint256) {
        return block.chainid;
    }
}
在较旧的以太坊版本（如 Byzantium）中，block.chainid 操作码不被支持，调用 getChainId() 会失败。

3. 行为异常
如果合约依赖某些操作码的行为，而这些操作码在目标环境中表现不同，可能会导致意外行为。

示例：

contract Create2Example {
    function deploy(bytes32 salt, bytes memory bytecode) public returns (address) {
        address addr;
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        return addr;
    }
}
在较旧的以太坊版本中，CREATE2 操作码不被支持，deploy 函数可能无法按预期工作。

3. 防御措施
1. 检查目标环境
在部署合约之前，检查目标链或环境是否支持合约中使用的所有操作码。

示例：

function checkChainId() public pure returns (bool) {
    uint256 chainId;
    assembly {
        chainId := chainid()
    }
    return chainId > 0;
}
在部署前调用此函数，确保 CHAINID 操作码被支持。

2. 使用兼容性检查
在合约中引入兼容性检查，确保在目标环境中能够正常执行。

示例：

function isCreate2Supported() public pure returns (bool) {
    bool supported;
    assembly {
        supported := gt(create2(0, 0, 0, 0), 0)
    }
    return supported;
}
在部署前调用此函数，确保 CREATE2 操作码被支持。

3. 避免使用已弃用或不稳定的操作码
避免使用已弃用或不稳定的操作码，如 CALLCODE，并使用替代方案（如 DELEGATECALL）。

示例：

function delegateCall(address target, bytes memory data) public returns (bool) {
    (bool success, ) = target.delegatecall(data);
    return success;
}
4. 测试跨环境兼容性
在多个环境（如主网、测试网、分叉链）中测试合约，确保其行为一致。

示例：

在 Goerli、Sepolia 等测试网中测试合约。
在 Hardhat 或 Foundry 中模拟不同以太坊版本。
5. 使用编译器版本检查
在合约中引入编译器版本检查，确保合约代码与目标环境兼容。

示例：

pragma solidity ^0.8.0;

contract VersionCheck {
    function checkVersion() public pure returns (string memory) {
        return "This contract is compatible with Solidity 0.8.x";
    }
}
4. 总结
Unsupported Opcodes 攻击利用了 EVM 操作码在不同环境或版本中的不兼容性，导致合约无法正常执行或产生意外行为。为了防御此类攻击，开发者应检查目标环境、使用兼容性检查、避免已弃用或不稳定的操作码、测试跨环境兼容性，并使用适当的编译器版本。通过这些措施，可以确保合约在各种环境中都能正常运行。
 */
