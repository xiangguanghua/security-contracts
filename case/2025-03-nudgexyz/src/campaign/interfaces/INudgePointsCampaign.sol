// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IBaseNudgeCampaign.sol";

interface INudgePointsCampaign is IBaseNudgeCampaign {
  error NativeTokenTransferFailed();
  error CampaignAlreadyPaused();
  error CampaignNotPaused();
  error InvalidInputArrayLengths();
  error InvalidTargetToken();
  error CampaignAlreadyExists();

  event PointsCampaignCreated(uint256 campaignId, uint32 holdingPeriodInSeconds, address targetToken);
  event CampaignsPaused(uint256[] campaigns);
  event CampaignsUnpaused(uint256[] campaigns);

  // q 谁创建活动，活动的钱谁来投？没有看到字段
  struct Campaign {
    // q 持有时间？ 活动开始时间记录在什么地方？
    uint32 holdingPeriodInSeconds;
    // q 奖励token，还是需要质押的token
    address targetToken;
    // q 活动id谁给值？
    uint256 pID;
    // q 这个值谁给？
    uint256 totalReallocatedAmount;
  }

  // e 创建积分活动
  function createPointsCampaign(
    uint256 campaignId,
    uint32 holdingPeriodInSeconds,
    address targetToken
  )
    external
    returns (Campaign memory);

  // e 批量创建积分活动
  // q 都是通过数组来传值，如何保证对应关系？
  // @audit info 批量创建活动，活动的对应关系？
  function createPointsCampaigns(
    uint256[] calldata campaignIds,
    uint32[] calldata holdingPeriods,
    address[] calldata targetTokens
  )
    external
    returns (Campaign[] memory);

  // q 批量暂停活动？
  function pauseCampaigns(uint256[] calldata campaigns) external;
  // q 批量解除暂停活动？
  function unpauseCampaigns(uint256[] calldata campaigns) external;
}
