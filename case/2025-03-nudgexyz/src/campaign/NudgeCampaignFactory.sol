// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

import "./NudgeCampaign.sol";
import "./interfaces/INudgeCampaignFactory.sol";

/// @title NudgeCampaignFactory
/// @notice Factory contract for deploying and managing NudgeCampaign contracts
/// @dev Uses OpenZeppelin's AccessControl for role-based permissions and Create2 for deterministic deployments
contract NudgeCampaignFactory is INudgeCampaignFactory, AccessControl {
  using SafeERC20 for IERC20;

  /*////////////////////////////////////////////////////////////////////////
                                 常量
  ///////////////////////////////////////////////////////////////////////*/
  // e 定义3个角色
  bytes32 public constant NUDGE_ADMIN_ROLE = keccak256("NUDGE_ADMIN_ROLE");
  bytes32 public constant NUDGE_OPERATOR_ROLE = keccak256("NUDGE_OPERATOR_ROLE");
  bytes32 public constant SWAP_CALLER_ROLE = keccak256("SWAP_CALLER_ROLE");

  address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /*////////////////////////////////////////////////////////////////////////
                                 状态变量
  ///////////////////////////////////////////////////////////////////////*/
  // q 应该设置未常量，除非你后期向调整
  // qanswer 改变量后期确实被管理员调整了
  uint16 public FEE_BPS = 1000; // 10% by default
  // q 这个地址什么用？
  address public nudgeTreasuryAddress;
  // q 这个mapping是干什么的？
  // qanswer 用于后面收集奖励用的
  mapping(address => bool) public isCampaign; // Campaign tracking
  // e 存储已部署的活动地址
  address[] public campaignAddresses;
  // e 记录活动地址，是否被暂停
  // q 会不会记录混乱，活动地址被暂停，但是没有记录
  mapping(address => bool) public isCampaignPaused;

  /// @notice Initializes the contract with required addresses and roles
  /// @param treasury_ Address of the treasury to collect fees
  /// @param admin_ Address to be granted NUDGE_ADMIN_ROLE
  /// @param operator_ Address to be granted NUDGE_OPERATOR_ROLE
  /// @param swapCaller_ Address to be granted SWAP_CALLER_ROLE
  /// @dev All parameters must be non-zero addresses
  // q 初始化授权地址，如果授权错误呢？会不会有什么影响？如何保证授权不会错误，普通用户是什么角色
  constructor(address treasury_, address admin_, address operator_, address swapCaller_) {
    if (treasury_ == address(0)) revert InvalidTreasuryAddress();
    if (admin_ == address(0)) revert ZeroAddress();
    if (operator_ == address(0)) revert ZeroAddress();
    if (swapCaller_ == address(0)) revert ZeroAddress();
    // q 这个地址什么用？
    nudgeTreasuryAddress = treasury_;

    _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    _grantRole(NUDGE_ADMIN_ROLE, admin_);
    _grantRole(NUDGE_OPERATOR_ROLE, operator_);
    _grantRole(SWAP_CALLER_ROLE, swapCaller_);
  }

  /// @notice Returns the total number of deployed campaigns
  /// @return The count of all campaigns deployed by this factory
  function getCampaignCount() external view returns (uint256) {
    return campaignAddresses.length;
  }

  /// @notice Deploys a new NudgeCampaign contract
  /// @param holdingPeriodInSeconds Duration users must hold tokens to be eligible for rewards
  /// @param targetToken Address of the token users need to hold
  /// @param rewardToken Address of the token used for rewards
  /// @param rewardPPQ The reward factor in parts per quadrillion for calculating rewards
  /// @param campaignAdmin Address of the campaign admin
  /// @param startTimestamp When the campaign starts
  /// @param alternativeWithdrawalAddress Optional address for alternative reward withdrawal
  /// @param uuid Unique identifier for the campaign
  /// @return campaign Address of the deployed campaign contract
  /// @dev Uses Create2 for deterministic address generation

  // e 部署活动，没有提供资金，后续需要用户自己提供资金
  // e 如果选择简单部署，之后可以通过向活动的合约地址发送一些代币来为活动提供资金。这也可以在任何时候用来“充值”活动。
  // q 如果后续不提供资金，怎么办？
  // q 部署失败怎么办
  function deployCampaign(
    uint32 holdingPeriodInSeconds, // e 持仓期
    address targetToken,
    address rewardToken, // e 奖励代币
    // e 奖励 PPQ 用于根据参与金额（toAmount）计算奖励的系数
    // q 如何计算奖励因子
    // q 调用这个方法的时候计算出来的，
    // @audit info 没有做校验，rewardPPQ的值是否合法
    uint256 rewardPPQ,
    address campaignAdmin, // e 部署活动的活动管理员（项目）的钱包地址
    uint256 startTimestamp, // e 开始时间戳, 营销开始的时间和日期。0 值将营销开始设置为立即
    // e 代替提款地址. 项目可能选择指定与营销管理员地址不同的地址来提取未分配的奖励。否则，在此处使用零地址将发送代币到营销管理员地址。
    // q 如何使用这个地址.为什么会有未分配的奖励,未分配奖励如何计算
    // q 前端传递过来的地址？
    // @audit info 难道不用做address(0) 校验？
    address alternativeWithdrawalAddress,
    // q campaignId_ 是 uuid 吗？如何生成uuid
    uint256 uuid
  )
    public
    returns (address campaign)
  {
    if (campaignAdmin == address(0)) revert ZeroAddress();
    if (targetToken == address(0) || rewardToken == address(0)) revert ZeroAddress();
    if (holdingPeriodInSeconds == 0) revert InvalidParameter();

    // Generate deterministic salt using all parameters
    bytes32 salt = keccak256(
      abi.encode(
        holdingPeriodInSeconds,
        targetToken,
        rewardToken,
        rewardPPQ,
        campaignAdmin,
        startTimestamp,
        FEE_BPS,
        alternativeWithdrawalAddress,
        uuid // @audit info 如果我让你两次生成的一样。那么。你就**。
      )
    );

    // Create constructor arguments
    bytes memory constructorArgs = abi.encode(
      holdingPeriodInSeconds,
      targetToken,
      rewardToken,
      rewardPPQ,
      campaignAdmin,
      startTimestamp,
      FEE_BPS,
      alternativeWithdrawalAddress,
      uuid
    );

    // Deploy using CREATE2
    bytes memory bytecode = abi.encodePacked(type(NudgeCampaign).creationCode, constructorArgs);
    // e return campaign address 值
    campaign = Create2.deploy(0, salt, bytecode);

    // q 这个mapping是干什么的？
    // qanswer 用于后面收集奖励用的
    isCampaign[campaign] = true; // Track the campaign
    // e 记录活动地址的值
    campaignAddresses.push(campaign);

    emit CampaignDeployed(campaign, campaignAdmin, targetToken, rewardToken, startTimestamp, uuid);
  }

  /// @notice Deploys a new campaign and funds it with initial rewards
  /// @param holdingPeriodInSeconds Duration users must hold tokens to be eligible for rewards
  /// @param targetToken Address of the token users need to hold
  /// @param rewardToken Address of the token used for rewards
  /// @param rewardPPQ The reward multiplier for calculating rewards
  /// @param campaignAdmin Address of the campaign administrator
  /// @param startTimestamp When the campaign starts
  /// @param alternativeWithdrawalAddress Optional address for alternative reward withdrawal
  /// @param initialRewardAmount Amount of reward tokens to fund the campaign with
  /// @param uuid Unique identifier for the campaign
  /// @return campaign Address of the deployed and funded campaign contract
  /// @dev If rewardToken is NATIVE_TOKEN, msg.value must be at least initialRewardAmount
  // e 部署并提供资金
  function deployAndFundCampaign(
    uint32 holdingPeriodInSeconds,
    address targetToken,
    address rewardToken,
    uint256 rewardPPQ,
    address campaignAdmin,
    uint256 startTimestamp,
    address alternativeWithdrawalAddress,
    // e 初始奖励金额
    // q 如果传入空值呢？
    uint256 initialRewardAmount,
    uint256 uuid
  )
    external
    payable
    returns (address campaign)
  {
    if (campaignAdmin == address(0)) revert ZeroAddress();
    if (targetToken == address(0) || rewardToken == address(0)) revert ZeroAddress();
    if (holdingPeriodInSeconds == 0) revert InvalidParameter();

    if (rewardToken == NATIVE_TOKEN) {
      if (msg.value != initialRewardAmount) revert IncorrectEtherAmount();
      // Deploy contract first
      // q 部署失败会怎么样？,返回值是什么
      campaign = deployCampaign(
        holdingPeriodInSeconds,
        targetToken,
        rewardToken,
        rewardPPQ,
        campaignAdmin,
        startTimestamp,
        alternativeWithdrawalAddress,
        uuid
      );
      // @audit-follow-up: Consider using a reentrancy guard
      // @audit info campaign address没有校验
      (bool sent,) = campaign.call{ value: initialRewardAmount }("");
      if (!sent) revert NativeTokenTransferFailed();
    } else {
      if (msg.value > 0) revert IncorrectEtherAmount();
      // q 部署失败会怎么样？,返回值是什么
      campaign = deployCampaign(
        holdingPeriodInSeconds,
        targetToken,
        rewardToken,
        rewardPPQ,
        campaignAdmin,
        startTimestamp,
        alternativeWithdrawalAddress,
        uuid
      );
      // @audit info campaign address没有校验
      IERC20(rewardToken).safeTransferFrom(msg.sender, campaign, initialRewardAmount);
    }
  }

  /// @notice Computes the deterministic address of a campaign based on its parameters
  /// @param holdingPeriodInSeconds Duration users must hold tokens to be eligible for rewards
  /// @param targetToken Address of the token users need to hold
  /// @param rewardToken Address of the token used for rewards
  /// @param rewardPPQ The reward multiplier for calculating rewards
  /// @param campaignAdmin Address of the campaign administrator
  /// @param startTimestamp When the campaign starts
  /// @param feeBps Nudge's fee percentage in basis points
  /// @param alternativeWithdrawalAddress Optional address for alternative reward withdrawal
  /// @param uuid Unique identifier for the campaign
  /// @return computedAddress The address where the campaign would be deployed
  /// @dev Uses the same parameters as deployCampaign to compute the Create2 address
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
    returns (address computedAddress)
  {
    bytes32 salt = keccak256(
      abi.encode(
        holdingPeriodInSeconds,
        targetToken,
        rewardToken,
        rewardPPQ,
        campaignAdmin,
        startTimestamp,
        feeBps,
        alternativeWithdrawalAddress,
        uuid
      )
    );

    bytes memory constructorArgs = abi.encode(
      holdingPeriodInSeconds,
      targetToken,
      rewardToken,
      rewardPPQ,
      campaignAdmin,
      startTimestamp,
      feeBps,
      alternativeWithdrawalAddress,
      uuid
    );

    bytes memory bytecode = abi.encodePacked(type(NudgeCampaign).creationCode, constructorArgs);

    computedAddress = Create2.computeAddress(salt, keccak256(bytecode), address(this));
  }

  /// @notice Updates the treasury address
  /// @param newTreasury New address for the treasury
  /// @dev Only callable by NUDGE_ADMIN_ROLE
  function updateTreasuryAddress(address newTreasury) external onlyRole(NUDGE_ADMIN_ROLE) {
    if (newTreasury == address(0)) revert InvalidTreasuryAddress();

    address oldTreasury = nudgeTreasuryAddress;
    nudgeTreasuryAddress = newTreasury;

    emit TreasuryUpdated(oldTreasury, newTreasury);
  }

  /// @notice Update Nudge's fee in basis points for future campaigns created by this factory
  /// @param newFeeBps New fee in basis points
  /// @dev Only callable by NUDGE_ADMIN_ROLE
  // q 这个newFeeBps是从哪里来的？
  function updateFeeSetting(uint16 newFeeBps) external onlyRole(NUDGE_ADMIN_ROLE) {
    if (newFeeBps > 10_000) revert InvalidFeeSetting();

    uint16 oldFeeBps = FEE_BPS;
    FEE_BPS = newFeeBps;
    emit FeeUpdated(oldFeeBps, newFeeBps);
  }

  /// @notice Collects accumulated fees from multiple campaigns
  /// @param campaigns Array of campaign addresses to collect fees from
  /// @dev Only callable by NUDGE_OPERATOR_ROLE
  function collectFeesFromCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_OPERATOR_ROLE) {
    uint256 totalAmount;
    // @audit info 如果是很多的活动呢？
    for (uint256 i = 0; i < campaigns.length; i++) {
      if (!isCampaign[campaigns[i]]) revert InvalidCampaign();
      // q 获取每个活动的奖励，collectFees里面具有有转账行为
      totalAmount += NudgeCampaign(payable(campaigns[i])).collectFees();
    }

    emit FeesCollected(campaigns, totalAmount);
  }

  /// @notice Pauses multiple campaigns
  /// @param campaigns Array of campaign addresses to pause
  /// @dev Only callable by NUDGE_ADMIN_ROLE
  function pauseCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_ADMIN_ROLE) {
    for (uint256 i = 0; i < campaigns.length; i++) {
      if (!isCampaign[campaigns[i]]) revert InvalidCampaign();
      if (isCampaignPaused[campaigns[i]]) revert CampaignAlreadyPaused();

      isCampaignPaused[campaigns[i]] = true;
    }

    emit CampaignsPaused(campaigns);
  }

  /// @notice Unpauses multiple campaigns
  /// @param campaigns Array of campaign addresses to unpause
  /// @dev Only callable by NUDGE_ADMIN_ROLE
  function unpauseCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_ADMIN_ROLE) {
    for (uint256 i = 0; i < campaigns.length; i++) {
      if (!isCampaign[campaigns[i]]) revert InvalidCampaign();
      if (!isCampaignPaused[campaigns[i]]) revert CampaignNotPaused();

      isCampaignPaused[campaigns[i]] = false;
    }

    emit CampaignsUnpaused(campaigns);
  }

  // q 为什么不支持暂停单个活动呢？
}
