// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/*
 * @author not-so-secure-dev
 * @title PasswordStore
 * @notice This contract allows you to store a private password that others won't be able to see. 
 * You can update your password at any time.
 */
contract PasswordStore {
    /*//////////////////////////////////////////////
                        错误
    //////////////////////////////////////////////*/
    error PasswordStore__NotOwner();

    /*//////////////////////////////////////////////
                        状态变量
    //////////////////////////////////////////////*/
    address private s_owner;
    // @audit The s_password is visible on the chain
    string private s_password;

    /*//////////////////////////////////////////////
                        事件
    //////////////////////////////////////////////*/
    event SetNetPassword();

    constructor() {
        s_owner = msg.sender;
    }

    /*//////////////////////////////////////////////
                        业务方法
    //////////////////////////////////////////////*/
    /*
     * @notice This function allows only the owner to set a new password.
     * @param newPassword The new password to set.
     */
    // @audit any user can set a new password
    function setPassword(string memory newPassword) external {
        s_password = newPassword;
        emit SetNetPassword();
    }

    /*
     * @notice This allows only the owner to retrieve the password.
     // @audit their is no newPassword parameter
     * @param newPassword The new password to set.
     */
    function getPassword() external view returns (string memory) {
        if (msg.sender != s_owner) {
            revert PasswordStore__NotOwner();
        }
        return s_password;
    }
}
