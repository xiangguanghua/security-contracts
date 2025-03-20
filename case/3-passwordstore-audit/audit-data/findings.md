### [H-1] 存储在链上的变量都是可见的，因此密码也是可见的

**Description:** 在链上所有的数据都是可见的，能直接从链上读取。根据协议说明`PasswordStore::s_password`的值只能由`PasswordStore::getPassword`方法访问，并且只能由管理员调用。

**Impact:** 任何人都能访问密码，这不属于协议规范

**Proof of Concept:** （使用代码证明）

以下是一段测试代码：  
1、创建本地运行环境

```bash
make anvil
```

2、部署合约至本地环境

```bash
make deploy
```

3、运行 cast 工具

```bash
cast storage <ADDRESS_HERE> 1 --rpc-url http://127.0.0.1:8545
```

使用`1`因为`s_password`在 Storage 的 slot 是 1

得到如下结果：
`0x6d7950617373776f726400000000000000000000000000000000000000000014`

使用命令行解析工具

```bash
cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
```

使用 hex 得到字符串：
myPassword

**Recommended Mitigation:** 因此，应该重新考虑合同的整体架构。人们可以在链下加密密码，然后将加密的密码存储在链上。这将要求用户记住链下的另一个密码来解密密码。但是，您也可能希望删除视图函数，因为您不希望用户意外地发送带有解密您的密码的密码的事务。

### [H-2] Title `PasswordStore::setPassword`没有访问权限限制，任何人都能更改密码

**Description:** `PasswordStore::setPassword`是一个 external 方法，方法注释：改方法只能 owner 调用并设置新密码。

```javascript
    function setPassword(string memory newPassword) external {
@>      // @audit - There are no access controls
        s_password = newPassword;
        emit SetNetPassword();
    }
```

**Impact:** 任何人都能使用此方法更改`s_password`的值.

**Proof of Concept:** 下面是`PasswordStore.t.sol`测试文件内容。

<details>
<summary>代码</summary>

```javascript
function test_anyone_can_set_password(address randomAddress) public {
        vm.assume(randomAddress != owner);

        vm.prank(randomAddress);
        string memory expectedPassword = "myNewPassword";
        passwordStore.setPassword(expectedPassword);

        vm.prank(owner);
        string memory actualPassword = passwordStore.getPassword();
        assertEq(actualPassword, expectedPassword);
}
```

</details>

**Recommended Mitigation:** 在`setPassword`方法中添加访问控制

```javascript
if(msg.sender != s_owner){
    revert PasswordStore_NotOwner();
}
```

### [I-1] Title `PasswordStore::getPassword()`指定了一个参数声明，但实际上并没有参数

**Impact:** 注释错误

**Proof of Concept:**

```javascript
    /*
     * @notice This allows only the owner to retrieve the password.
@>   * @param newPassword The new password to set.
     */
    function getPassword() external view returns (string memory) {
        if (msg.sender != s_owner) {
            revert PasswordStore__NotOwner();
        }
        return s_password;
    }
```

**Recommended Mitigation:** 删除无效注释

```diff
-  * @param newPassword The new password to set.
```
