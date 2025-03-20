// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Vulnerable contract storing unencrypted private data
contract OddEven {
    struct Player {
        address payable addr;
        uint256 number;
    }

    Player[2] private players;
    uint8 count = 0;

    function play(uint256 number) public payable {
        require(msg.value == 1 ether);
        players[count] = Player(payable(msg.sender), number);
        count++;
        if (count == 2) selectWinner();
    }

    function selectWinner() private {
        uint256 n = players[0].number + players[1].number;
        players[n % 2].addr.transfer(address(this).balance);
        delete players;
        count = 0;
    }
}
