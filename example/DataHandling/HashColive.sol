// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Hashcash {
    string a = "A";
    string b = "B";
    string ab = "AB";

    function abiEncod() public view returns (bytes memory, bytes memory) {
        return (abi.encode(a, b), abi.encode(ab));
    }

    function abiEncodPacked() public view returns (bytes memory, bytes memory) {
        return (abi.encodePacked(a, b), abi.encodePacked(ab));
    }
}
