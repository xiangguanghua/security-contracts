// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
Unbounded Return Data 攻击 是一种利用 Solidity 合约中未限制外部调用返回数据大小而导致的攻击方式。
当合约调用外部合约时，如果未限制返回数据的大小，攻击者可能通过返回大量数据耗尽合约的 Gas，导致交易失败或合约功能被瘫痪。

攻击原理：
在 Solidity 中，外部调用（如 call、delegatecall 或 staticcall）可以返回任意大小的数据。如果合约未限制返回数据的大小，可能会出现以下问题：
1、Gas 耗尽：攻击者通过返回大量数据，使合约在处理返回数据时耗尽 Gas，导致交易失败。
2、合约功能瘫痪：如果合约的关键操作依赖于外部调用的返回数据，攻击者可以通过返回大量数据阻止这些操作。
 */

/*
示例 1：未限制返回数据大小

问题分析：
1、如果 target 是一个恶意合约，并且返回大量数据，callExternal 函数可能会在处理返回数据时耗尽 Gas。
2、这可能导致交易失败或合约功能被瘫痪。
 */
contract UnboundedReturnData {
    function callExternal(address target) public returns (bytes memory) {
        // 未限制返回数据大小
        (bool success, bytes memory data) = target.call("");
        require(success, "Call failed");
        return data;
    }
}

/*
示例 2：依赖返回数据的操作

问题分析：
1、如果 target 是一个恶意合约，并且返回大量数据，processData 函数可能会在处理返回数据时耗尽 Gas。
2、这可能导致交易失败或合约功能被瘫痪。
 */
contract DependentOnReturnData {
    function processData(address target) public {
        // 依赖返回数据的操作
        (bool success, bytes memory data) = target.call("");
        require(success, "Call failed");
        // 处理返回数据
        require(data.length > 0, "No data returned");
    }
}

/*
解决方法


1. 限制返回数据大小
在外部调用后，检查返回数据的大小，确保其不超过预期范围。
pragma solidity ^0.8.0;
contract BoundedReturnData {
    function callExternal(address target) public returns (bytes memory) {
        // 限制返回数据大小
        (bool success, bytes memory data) = target.call("");
        require(success, "Call failed");
        require(data.length <= 1024, "Return data too large");
        return data;
    }
}

2. 使用 staticcall 代替 call
staticcall 是一种只读的外部调用，可以避免返回数据过大导致的 Gas 耗尽问题。
pragma solidity ^0.8.0;
contract UseStaticCall {
    function callExternal(address target) public returns (bytes memory) {
        // 使用 staticcall
        (bool success, bytes memory data) = target.staticcall("");
        require(success, "Call failed");
        return data;
    }
}

3. 避免依赖返回数据
在合约设计中，避免依赖外部调用的返回数据，减少攻击面。
pragma solidity ^0.8.0;
contract AvoidDependency {
    function processData(address target) public {
        // 不依赖返回数据的操作
        (bool success, ) = target.call("");
        require(success, "Call failed");
    }
}

4. 使用 Gas Limit
在外部调用时，设置 Gas 限制，避免因返回数据过大而耗尽 Gas。
pragma solidity ^0.8.0;
contract UseGasLimit {
    function callExternal(address target) public returns (bytes memory) {
        // 设置 Gas 限制
        (bool success, bytes memory data) = target.call{gas: 100000}("");
        require(success, "Call failed");
        return data;
    }
}

总结
Unbounded Return Data 攻击是一种利用 Solidity 外部调用返回数据大小未限制而导致的攻击方式，可能导致 Gas 耗尽或合约功能被瘫痪。通过以下方法可以有效避免这种问题：
限制返回数据大小。
使用 staticcall 代替 call。
避免依赖返回数据。
设置 Gas 限制。
 */
