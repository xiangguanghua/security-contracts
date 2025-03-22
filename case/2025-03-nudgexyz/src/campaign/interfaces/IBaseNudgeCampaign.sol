// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// e 基础的活动接口
interface IBaseNudgeCampaign {
  // Errors
  // e 该协议支持暂停
  error CampaignPaused();
  error UnauthorizedSwapCaller();
  error Unauthorized();
  error InsufficientAmountReceived();
  error InvalidToTokenReceived(address toToken);

  // Enums
  enum ParticipationStatus {
    PARTICIPATING,
    INVALIDATED,
    CLAIMED,
    HANDLED_OFFCHAIN
  }

  // Structs
  struct Participation {
    ParticipationStatus status;
    address userAddress;
    uint256 toAmount; // Amount of tokens the user sent to the campaign
    uint256 rewardAmount; //
    uint256 startTimestamp;
    uint256 startBlockNumber;
  }

  // Events
  event NewParticipation(
    uint256 indexed campaignId,
    address indexed userAddress,
    uint256 pID,
    uint256 toAmount,
    uint256 entitledRewards,
    uint256 fees,
    bytes data
  );

  // External functions
  // e 活动积分和活动实现该方法
  // q 用户往活动里面充钱，还是从活动里面提钱？？
  function handleReallocation(
    uint256 campaignId,
    address userAddress,
    address toToken,
    uint256 toAmount,
    bytes memory data
  )
    external
    payable;

  // View functions
  function getBalanceOfSelf(address token) external view returns (uint256);
}
