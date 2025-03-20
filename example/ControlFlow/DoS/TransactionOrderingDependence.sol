// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
Transaction-Ordering Dependence 攻击（交易顺序依赖攻击，又称 Front-Running 攻击）是一种利用区块链中交易顺序的不确定性来获取利益的攻击方式。
攻击者通过观察未确认的交易，发送一笔具有更高 Gas 价格的交易，使其优先被矿工打包，从而影响合约的执行结果。

攻击原理：
在以太坊等区块链中，交易的执行顺序取决于矿工的打包顺序，而矿工通常会优先打包 Gas 价格更高的交易。攻击者利用这一机制，通过以下步骤实施攻击：
1、观察未确认的交易：攻击者监控内存池（mempool）中的未确认交易。
2、发送高 Gas 价格交易：攻击者发送一笔与目标交易类似但具有更高 Gas 价格的交易。
3、优先执行：由于 Gas 价格更高，攻击者的交易被矿工优先打包，从而影响合约的执行结果。
 */

/*
示例 1：拍卖合约中的 Front-Running

问题分析：
攻击者可以观察到一个高额出价的交易，并发送一笔具有更高 Gas 价格的交易，将自己的出价设为最高。
当攻击者的交易被优先打包后，原高额出价者的资金会被返还，而攻击者成为新的最高出价者。

*/
contract Auction {
    address public highestBidder;
    uint256 public highestBid;

    function bid() public payable {
        require(msg.value > highestBid, "Bid must be higher than current highest bid");
        // 返还前一个最高出价者的资金
        payable(highestBidder).transfer(highestBid);
        // 更新最高出价
        highestBidder = msg.sender;
        highestBid = msg.value;
    }
}

contract KingOfEther {
    address public king;
    uint256 public balance;

    function claimThrone() external payable {
        require(msg.value > balance, "Need to pay more to become the king");

        (bool sent,) = king.call{value: balance}("");
        require(sent, "Failed to send Ether");

        balance = msg.value;
        king = msg.sender;
    }
}

contract Attack {
    KingOfEther kingOfEther;

    constructor(KingOfEther _kingOfEther) {
        kingOfEther = KingOfEther(_kingOfEther);
    }

    // fallback() external payable {
    //     assert(false);
    // }

    function attack() public payable {
        kingOfEther.claimThrone{value: msg.value}();
    }
}

/*
示例 2：去中心化交易所（DEX）中的 Front-Running

问题分析：
攻击者可以观察到一笔大额兑换交易，并发送一笔具有更高 Gas 价格的交易，优先执行兑换操作。
由于交易顺序被改变，攻击者可能以更有利的价格完成兑换，从而获取额外利益。
 */
contract DEX {
    mapping(address => uint256) public balances;

    function swap(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        // 执行兑换操作
        uint256 outputAmount = amount * getPrice();
        balances[msg.sender] -= amount;
        balances[msg.sender] += outputAmount;
    }

    function getPrice() public pure returns (uint256) {
        // 假设价格为固定值
        return 1 ether;
    }
}

/*
解决方法
1. 使用 Commit-Reveal 机制
将交易分为两个阶段：提交（Commit）和揭示（Reveal）。
1、在提交阶段，用户提交交易的哈希值；
2、在揭示阶段，用户揭示交易的具体内容。这样可以隐藏交易细节，防止 Front-Running。

contract CommitRevealAuction {
    struct Bid {
        bytes32 commit;
        uint256 amount;
        bool revealed;
    }

    mapping(address => Bid) public bids;
    address public highestBidder;
    uint256 public highestBid;

    function commitBid(bytes32 commit) public {
        bids[msg.sender] = Bid(commit, 0, false);
    }

    function revealBid(uint256 amount, bytes32 secret) public {
        Bid storage bid = bids[msg.sender];
        require(!bid.revealed, "Bid already revealed");
        require(keccak256(abi.encodePacked(amount, secret)) == bid.commit, "Invalid reveal");

        bid.amount = amount;
        bid.revealed = true;

        if (amount > highestBid) {
            highestBidder = msg.sender;
            highestBid = amount;
        }
    }
}
2. 使用批量交易
将多个交易打包成一笔交易，确保它们的执行顺序不会被改变。

3. 调整 Gas 价格
在敏感操作中，设置较高的 Gas 价格，减少被 Front-Running 的可能性。

4. 使用隐私保护技术
例如零知识证明（zk-SNARKs）或可信执行环境（TEE），隐藏交易细节。

5. 限制交易的可预测性
在合约设计中，避免暴露可被攻击者利用的信息。

总结
Transaction-Ordering Dependence 攻击是一种利用区块链交易顺序不确定性来获取利益的攻击方式。通过以下方法可以有效避免这种问题：

使用 Commit-Reveal 机制隐藏交易细节。
将多个交易打包成一笔交易。
设置较高的 Gas 价格。
使用隐私保护技术。
在合约设计中限制交易的可预测性。
 */
contract FindThisHash {
    bytes32 public constant hash = 0x564ccaf7594d66b1eaaea24fe01f0585bf52ee70852af4eac0cc4b04711cd0e2;

    constructor() payable {}

    function solve(string memory solution) public {
        require(hash == keccak256(abi.encodePacked(solution)), "Incorrect answer");
        (bool sent,) = msg.sender.call{value: 10 ether}("");
        require(sent, "Failed to send Ether");
    }
}

contract SecuredFindThisHash {
    // Struct is used to store the commit details
    struct Commit {
        bytes32 solutionHash;
        uint256 commitTime;
        bool revealed;
    }
    // The hash that is needed to be solved

    bytes32 public hash = 0x564ccaf7594d66b1eaaea24fe01f0585bf52ee70852af4eac0cc4b04711cd0e2;
    // Address of the winner
    address public winner;
    // Price to be rewarded
    uint256 public reward;
    // Status of game
    bool public ended;
    // Mapping to store the commit details with address
    mapping(address => Commit) commits;
    // Modifier to check if the game is active

    modifier gameActive() {
        require(!ended, "Already ended");
        _;
    }

    constructor() payable {
        reward = msg.value;
    }
    /* 
       Commit function to store the hash calculated using keccak256(address + solution + secret). 
       Users can only commit once and if the game is active.
    */

    function commitSolution(bytes32 _solutionHash) public gameActive {
        Commit storage commit = commits[msg.sender];
        require(commit.commitTime == 0, "Already committed");
        commit.solutionHash = _solutionHash;
        commit.commitTime = block.timestamp;
        commit.revealed = false;
    }
    /* 
        Function to get the commit details. It returns a tuple of (solutionHash, commitTime, revealStatus);  
        Users can get solution only if the game is active and they have committed a solutionHash
    */

    function getMySolution() public view gameActive returns (bytes32, uint256, bool) {
        Commit storage commit = commits[msg.sender];
        require(commit.commitTime != 0, "Not committed yet");
        return (commit.solutionHash, commit.commitTime, commit.revealed);
    }
    /* 
        Function to reveal the commit and get the reward. 
        Users can get reveal solution only if the game is active and they have committed a solutionHash before this block and not revealed yet.
        It generates an keccak256(msg.sender + solution + secret) and checks it with the previously commited hash.  
        Assuming that a commit was already included on chain, front runners will not be able to pass this check since the msg.sender is different.
        Then the actual solution is checked using keccak256(solution), if the solution matches, the winner is declared, 
        the game is ended and the reward amount is sent to the winner.
    */

    function revealSolution(string memory _solution, string memory _secret) public gameActive {
        Commit storage commit = commits[msg.sender];
        require(commit.commitTime != 0, "Not committed yet");
        require(commit.commitTime < block.timestamp, "Cannot reveal in the same block");
        require(!commit.revealed, "Already commited and revealed");
        bytes32 solutionHash = keccak256(abi.encodePacked(msg.sender, _solution, _secret));
        require(solutionHash == commit.solutionHash, "Hash doesn't match");
        require(keccak256(abi.encodePacked(_solution)) == hash, "Incorrect answer");
        winner = msg.sender;
        ended = true;
        (bool sent,) = payable(msg.sender).call{value: reward}("");
        if (!sent) {
            winner = address(0);
            ended = false;
            revert("Failed to send ether.");
        }
    }
}
