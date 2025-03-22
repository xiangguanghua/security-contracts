// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/IAccessControl.sol";

interface INudgeCampaignFactory is IAccessControl {
  // e 取角色的值，角色的值在实现中定义
  function NUDGE_ADMIN_ROLE() external view returns (bytes32);
  function NUDGE_OPERATOR_ROLE() external view returns (bytes32);
  function SWAP_CALLER_ROLE() external view returns (bytes32);
  function NATIVE_TOKEN() external view returns (address);

  error ZeroAddress();
  error InvalidTreasuryAddress();
  error InvalidParameter();
  error InvalidCampaign();
  error CampaignAlreadyPaused();
  error CampaignNotPaused();
  error NativeTokenTransferFailed();
  error IncorrectEtherAmount();
  error InvalidFeeSetting();

  // e 部署活动事件
  event CampaignDeployed(
    address indexed campaign,
    address indexed admin,
    address targetToken,
    address rewardToken,
    uint256 startTimestamp,
    uint256 uuid
  );
  event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
  event CampaignsPaused(address[] campaigns);
  event CampaignsUnpaused(address[] campaigns);
  event FeesCollected(address[] campaigns, uint256 totalAmount);
  event FeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);

  function nudgeTreasuryAddress() external view returns (address);
  function isCampaign(address) external view returns (bool);
  function campaignAddresses(uint256) external view returns (address);
  function isCampaignPaused(address) external view returns (bool);

  // q 部署活动地址，部署成功后，活动地址存储起来没有？
  function deployCampaign(
    uint32 holdingPeriodInSeconds,
    address targetToken,
    address rewardToken,
    uint256 rewardPPQ,
    address campaignAdmin,
    uint256 startTimestamp,
    address alternativeWithdrawalAddress,
    uint256 uuid
  )
    external
    returns (address);

  // q 部署活动地址并且存钱，活动地址存储起来没有？
  function deployAndFundCampaign(
    uint32 holdingPeriodInSeconds,
    address targetToken,
    address rewardToken,
    uint256 rewardPPQ,
    address campaignAdmin,
    uint256 startTimestamp,
    address alternativeWithdrawalAddress,
    uint256 initialRewardAmount,
    uint256 uuid
  )
    external
    payable
    returns (address);

  // q 获取活动地址需要这么多参数吗？
  function getCampaignAddress(
    uint32 holdingPeriodInSeconds,
    address targetToken,
    address rewardToken,
    uint256 rewardPPQ,
    address campaignAdmin,
    uint256 startTimestamp,
    uint16 feeBps,
    address alternativeWithdrawalAddress,
    uint256 uuid
  )
    external
    view
    returns (address);

  // q 宝藏地址是什么？
  function updateTreasuryAddress(address newTreasury) external;
  // q 什么fee？
  function updateFeeSetting(uint16 newFeeBps) external;
  // q 积累活动费用功能吗？
  function collectFeesFromCampaigns(address[] calldata campaigns) external;

  // e 暂停和解除暂停 活动
  function pauseCampaigns(address[] calldata campaigns) external;
  function unpauseCampaigns(address[] calldata campaigns) external;
}
