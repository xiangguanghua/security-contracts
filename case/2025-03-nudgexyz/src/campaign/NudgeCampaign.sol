// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import { INudgeCampaign } from "./interfaces/INudgeCampaign.sol";
import "./interfaces/INudgeCampaignFactory.sol";

contract NudgeCampaign is INudgeCampaign, AccessControl {
  using Math for uint256;
  using SafeERC20 for IERC20;

  /*////////////////////////////////////////////////////////////////////////
                                 常量
          ///////////////////////////////////////////////////////////////////////*/
  bytes32 public constant CAMPAIGN_ADMIN_ROLE = keccak256("CAMPAIGN_ADMIN_ROLE");
  // q 我也不知道为什么是10000
  uint256 private constant BPS_DENOMINATOR = 10_000;
  // qanswer 奖励因子，每十亿分之一, 用于根据参与金额（toAmount）计算奖励的系数
  uint256 private constant PPQ_DENOMINATOR = 1e15; // Denominator in parts per quadrillion
  address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /*////////////////////////////////////////////////////////////////////////
                                 不变量
          ///////////////////////////////////////////////////////////////////////*/
  // Factory reference
  INudgeCampaignFactory public immutable factory;
  // Campaign Configuration
  uint32 public immutable holdingPeriodInSeconds;
  address public immutable targetToken;
  address public immutable rewardToken;
  uint256 public immutable rewardPPQ;
  uint256 public immutable startTimestamp;
  address public immutable alternativeWithdrawalAddress;
  // qanswer 就是uuid
  uint256 public immutable campaignId; // Unique identifier for this campaign
  // qanswer token的18位放大系数，如 10**(18-TD)
  uint256 public immutable targetScalingFactor; // Scaling factors for 18 decimal normalization
  uint256 public immutable rewardScalingFactor;
  // qanswer 收取rewardAmmout费用的比例。fee = rewardAmount * feeBps , 支持管理员后期更新
  uint16 public feeBps; // Fee parameter in basis points (1000 = 10%)
  // qanswer 记录活动是否激活
  bool public isCampaignActive;

  /*////////////////////////////////////////////////////////////////////////
                                 状态变量
          ///////////////////////////////////////////////////////////////////////*/
  // Campaign State
  // qanswer 参加活动的人数编码
  uint256 public pID;
  // qanswer 待发放奖励
  uint256 public pendingRewards; // e handleReallocation() 方法中计算
  // qanswer 总共投入的金额
  uint256 public totalReallocatedAmount;
  // qanswer 积累的手续费
  uint256 public accumulatedFees; // e handleReallocation() 方法中计算
  // qanswer 已经分配的奖励
  uint256 public distributedRewards;
  // Track whether campaign was manually deactivated
  // q 这个是什么，这个值在什么时候确认的？
  bool private _manuallyDeactivated;
  // Participations
  mapping(uint256 pID => Participation) public participations;

  /// @notice Ensures the campaign is not paused
  modifier whenNotPaused() {
    if (factory.isCampaignPaused(address(this))) revert CampaignPaused();
    _;
  }

  /// @notice Restricts access to factory contract or Nudge admins
  modifier onlyFactoryOrNudgeAdmin() {
    if (!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender) && msg.sender != address(factory)) {
      revert Unauthorized();
    }
    _;
  }

  /// @notice Restricts access to Nudge operators
  modifier onlyNudgeOperator() {
    if (!factory.hasRole(factory.NUDGE_OPERATOR_ROLE(), msg.sender)) {
      revert Unauthorized();
    }
    _;
  }

  constructor(
    uint32 holdingPeriodInSeconds_,
    address targetToken_,
    address rewardToken_,
    uint256 rewardPPQ_,
    address campaignAdmin,
    uint256 startTimestamp_,
    uint16 feeBps_,
    address alternativeWithdrawalAddress_,
    uint256 campaignId_
  ) {
    if (rewardToken_ == address(0) || campaignAdmin == address(0)) {
      revert InvalidCampaignSettings();
    }

    if (startTimestamp_ != 0 && startTimestamp_ <= block.timestamp) {
      revert InvalidCampaignSettings();
    }

    // qanswer msg.sender就是工厂合约的地址
    factory = INudgeCampaignFactory(msg.sender);

    targetToken = targetToken_;
    rewardToken = rewardToken_;
    campaignId = campaignId_;

    uint256 targetDecimals = targetToken_ == NATIVE_TOKEN ? 18 : IERC20Metadata(targetToken_).decimals();
    uint256 rewardDecimals = rewardToken_ == NATIVE_TOKEN ? 18 : IERC20Metadata(rewardToken_).decimals();

    // Calculate scaling factors to normalize to 18 decimals
    targetScalingFactor = 10 ** (18 - targetDecimals);
    rewardScalingFactor = 10 ** (18 - rewardDecimals);

    _grantRole(CAMPAIGN_ADMIN_ROLE, campaignAdmin);

    startTimestamp = startTimestamp_ == 0 ? block.timestamp : startTimestamp_;
    // Campaign is active if start time is now or in the past
    isCampaignActive = startTimestamp <= block.timestamp;

    // Initialize as not manually deactivated
    _manuallyDeactivated = false;
    rewardPPQ = rewardPPQ_;
    holdingPeriodInSeconds = holdingPeriodInSeconds_;
    feeBps = feeBps_;
    alternativeWithdrawalAddress = alternativeWithdrawalAddress_;
  }

  function getRewardAmountIncludingFees(uint256 toAmount) public view returns (uint256) {
    if (targetScalingFactor == 1 && rewardScalingFactor == 1) {
      return toAmount.mulDiv(rewardPPQ, PPQ_DENOMINATOR);
    }

    uint256 scaledAmount = toAmount * targetScalingFactor;
    uint256 rewardAmountIn18Decimals = scaledAmount.mulDiv(rewardPPQ, PPQ_DENOMINATOR);
    return rewardAmountIn18Decimals / rewardScalingFactor;
  }

  /// @notice Handles token reallocation for campaign participation
  /// @param campaignId_ ID of the campaign
  /// @param userAddress Address of the participating user
  /// @param toToken Address of the token being acquired
  /// @param toAmount Expected amount of tokens to be acquired
  /// @param data Additional data for the reallocation
  /// @dev Only callable by SWAP_CALLER_ROLE, handles both ERC20 and native tokens
  function handleReallocation(
    uint256 campaignId_,
    address userAddress,
    address toToken,
    uint256 toAmount,
    bytes memory data
  )
    external
    payable
    whenNotPaused
  {
    // Check if campaign is active or can be activated
    _validateAndActivateCampaignIfReady();

    if (!factory.hasRole(factory.SWAP_CALLER_ROLE(), msg.sender)) {
      revert UnauthorizedSwapCaller();
    }

    if (toToken != targetToken) {
      revert InvalidToTokenReceived(toToken);
    }

    if (campaignId_ != campaignId) {
      revert InvalidCampaignId();
    }

    uint256 amountReceived;
    if (toToken == NATIVE_TOKEN) {
      amountReceived = msg.value;
    } else {
      if (msg.value > 0) {
        revert InvalidToTokenReceived(NATIVE_TOKEN);
      }
      IERC20 tokenReceived = IERC20(toToken);
      uint256 balanceOfSender = tokenReceived.balanceOf(msg.sender);
      uint256 balanceBefore = getBalanceOfSelf(toToken);
      SafeERC20.safeTransferFrom(tokenReceived, msg.sender, address(this), balanceOfSender);
      amountReceived = getBalanceOfSelf(toToken) - balanceBefore;
    }

    if (amountReceived < toAmount) {
      revert InsufficientAmountReceived();
    }
    // Why transfer amountReceived to user addresses?
    _transfer(toToken, userAddress, amountReceived);

    totalReallocatedAmount += amountReceived;

    uint256 rewardAmountIncludingFees = getRewardAmountIncludingFees(amountReceived);

    uint256 rewardsAvailable = claimableRewardAmount();
    if (rewardAmountIncludingFees > rewardsAvailable) {
      revert NotEnoughRewardsAvailable();
    }

    (uint256 userRewards, uint256 fees) = calculateUserRewardsAndFees(rewardAmountIncludingFees);
    pendingRewards += userRewards;
    accumulatedFees += fees;

    pID++;
    // Store the participation details
    participations[pID] = Participation({
      status: ParticipationStatus.PARTICIPATING,
      userAddress: userAddress,
      toAmount: amountReceived,
      rewardAmount: userRewards,
      startTimestamp: block.timestamp,
      startBlockNumber: block.number
    });

    emit NewParticipation(campaignId_, userAddress, pID, amountReceived, userRewards, fees, data);
  }

  /// @notice Claims rewards for multiple participations
  /// @param pIDs Array of participation IDs to claim rewards for
  /// @dev Verifies holding period, caller and participation status, and handles reward distribution
  function claimRewards(uint256[] calldata pIDs) external whenNotPaused {
    if (pIDs.length == 0) {
      revert EmptyParticipationsArray();
    }

    uint256 availableBalance = getBalanceOfSelf(rewardToken);

    for (uint256 i = 0; i < pIDs.length; i++) {
      Participation storage participation = participations[pIDs[i]];

      // Check if participation exists and is valid
      if (participation.status != ParticipationStatus.PARTICIPATING) {
        revert InvalidParticipationStatus(pIDs[i]);
      }

      // Verify that caller is the participation address
      if (participation.userAddress != msg.sender) {
        revert UnauthorizedCaller(pIDs[i]);
      }

      // Verify holding period has elapsed
      if (block.timestamp < participation.startTimestamp + holdingPeriodInSeconds) {
        revert HoldingPeriodNotElapsed(pIDs[i]);
      }

      uint256 userRewards = participation.rewardAmount;
      // Break if insufficient balance for this claim
      if (userRewards > availableBalance) {
        break;
      }

      // Update contract state
      pendingRewards -= userRewards;
      distributedRewards += userRewards;

      // Update participation status and transfer rewards
      participation.status = ParticipationStatus.CLAIMED;
      availableBalance -= userRewards;
      _transfer(rewardToken, participation.userAddress, userRewards);

      emit NudgeRewardClaimed(pIDs[i], participation.userAddress, userRewards);
    }
  }

  /*//////////////////////////////////////////////////////////////////////////
                              ADMIN FUNCTIONS                             
          //////////////////////////////////////////////////////////////////////////*/

  /// @notice Invalidates specified participations
  /// @param pIDs Array of participation IDs to invalidate
  /// @dev Only callable by operator role
  function invalidateParticipations(uint256[] calldata pIDs) external onlyNudgeOperator {
    for (uint256 i = 0; i < pIDs.length; i++) {
      Participation storage participation = participations[pIDs[i]];

      if (participation.status != ParticipationStatus.PARTICIPATING) {
        continue;
      }

      participation.status = ParticipationStatus.INVALIDATED;
      pendingRewards -= participation.rewardAmount;
    }

    emit ParticipationInvalidated(pIDs);
  }

  /// @notice Withdraws unallocated rewards from the campaign
  /// @param amount Amount of rewards to withdraw
  /// @dev Only callable by campaign admin
  function withdrawRewards(uint256 amount) external onlyRole(CAMPAIGN_ADMIN_ROLE) {
    if (amount > claimableRewardAmount()) {
      revert NotEnoughRewardsAvailable();
    }
    address to = alternativeWithdrawalAddress == address(0) ? msg.sender : alternativeWithdrawalAddress;

    _transfer(rewardToken, to, amount);

    emit RewardsWithdrawn(to, amount);
  }

  /// @notice Collects accumulated fees
  /// @return feesToCollect Amount of fees collected
  /// @dev Only callable by NudgeCampaignFactory or Nudge admins
  function collectFees() external onlyFactoryOrNudgeAdmin returns (uint256 feesToCollect) {
    feesToCollect = accumulatedFees;
    accumulatedFees = 0;

    _transfer(rewardToken, factory.nudgeTreasuryAddress(), feesToCollect);

    emit FeesCollected(feesToCollect);
  }

  /// @notice Marks a campaign as active, i.e accepting new participations
  /// @param isActive New active status
  /// @dev Only callable by Nudge admins
  function setIsCampaignActive(bool isActive) external {
    if (!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender)) {
      revert Unauthorized();
    }

    if (isActive && block.timestamp < startTimestamp) {
      revert StartDateNotReached();
    }

    isCampaignActive = isActive;
    // If deactivating, mark as manually deactivated
    if (!isActive) {
      _manuallyDeactivated = true;
    } else {
      // If activating, clear the manual deactivation flag
      _manuallyDeactivated = false;
    }

    emit CampaignStatusChanged(isActive);
  }

  /// @notice Rescues tokens that were mistakenly sent to the contract
  /// @param token Address of token to rescue
  /// @dev Only callable by NUDGE_ADMIN_ROLE, can't rescue the reward token
  /// @return amount Amount of tokens rescued
  function rescueTokens(address token) external returns (uint256 amount) {
    if (!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender)) {
      revert Unauthorized();
    }

    if (token == rewardToken) {
      revert CannotRescueRewardToken();
    }

    amount = getBalanceOfSelf(token);
    if (amount > 0) {
      _transfer(token, msg.sender, amount);
      emit TokensRescued(token, amount);
    }

    return amount;
  }

  /*//////////////////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS                              
          //////////////////////////////////////////////////////////////////////////*/

  /// @notice Gets the balance of the specified token for this contract
  /// @param token Address of token to check
  /// @return Balance of the token
  function getBalanceOfSelf(address token) public view returns (uint256) {
    if (token == NATIVE_TOKEN) {
      return address(this).balance;
    } else {
      return IERC20(token).balanceOf(address(this));
    }
  }

  /// @notice Calculates the amount of rewards available for distribution
  /// @return Amount of claimable rewards
  function claimableRewardAmount() public view returns (uint256) {
    return getBalanceOfSelf(rewardToken) - pendingRewards - accumulatedFees;
  }

  /// @notice Calculates user rewards and fees from total reward amount
  /// @param rewardAmountIncludingFees Total reward amount including fees
  /// @return userRewards Amount of rewards for the user
  /// @return fees Amount of fees to be collected
  function calculateUserRewardsAndFees(uint256 rewardAmountIncludingFees)
    public
    view
    returns (uint256 userRewards, uint256 fees)
  {
    fees = (rewardAmountIncludingFees * feeBps) / BPS_DENOMINATOR;
    userRewards = rewardAmountIncludingFees - fees;
  }

  /// @notice Returns comprehensive information about the campaign
  /// @return _holdingPeriodInSeconds Duration users must hold tokens
  /// @return _targetToken Address of token users need to hold
  /// @return _rewardToken Address of token used for rewards
  /// @return _rewardPPQ Reward parameter in parts per quadrillion
  /// @return _startTimestamp When the campaign becomes active
  /// @return _isCampaignActive Whether the campaign is currently active
  /// @return _pendingRewards Total rewards pending claim
  /// @return _totalReallocatedAmount Total amount of tokens reallocated
  /// @return _distributedRewards Total rewards distributed
  /// @return _claimableRewards Amount of rewards available for distribution
  function getCampaignInfo()
    external
    view
    returns (
      uint32 _holdingPeriodInSeconds,
      address _targetToken,
      address _rewardToken,
      uint256 _rewardPPQ,
      uint256 _startTimestamp,
      bool _isCampaignActive,
      uint256 _pendingRewards,
      uint256 _totalReallocatedAmount,
      uint256 _distributedRewards,
      uint256 _claimableRewards
    )
  {
    return (
      holdingPeriodInSeconds,
      targetToken,
      rewardToken,
      rewardPPQ,
      startTimestamp,
      isCampaignActive,
      pendingRewards,
      totalReallocatedAmount,
      distributedRewards,
      claimableRewardAmount()
    );
  }

  /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
          //////////////////////////////////////////////////////////////////////////*/
  /// @notice Internal function to transfer tokens
  /// @param token Address of token to transfer
  /// @param to Recipient address
  /// @param amount Amount to transfer
  /// @dev Handles both ERC20 and native token transfers
  function _transfer(address token, address to, uint256 amount) internal {
    if (token == NATIVE_TOKEN) {
      (bool sent,) = to.call{ value: amount }("");
      if (!sent) revert NativeTokenTransferFailed();
    } else {
      SafeERC20.safeTransfer(IERC20(token), to, amount);
    }
  }

  /// @notice Checks if campaign is active or can be activated based on current timestamp
  function _validateAndActivateCampaignIfReady() internal {
    if (!isCampaignActive) {
      // Only auto-activate if campaign has not been manually deactivated
      // and if the start time has been reached
      if (!_manuallyDeactivated && block.timestamp >= startTimestamp) {
        // Automatically activate the campaign if start time reached
        isCampaignActive = true;
      } else if (block.timestamp < startTimestamp) {
        // If start time not reached, explicitly revert
        revert StartDateNotReached();
      } else {
        // If campaign was manually deactivated, revert with InactiveCampaign
        revert InactiveCampaign();
      }
    }
  }

  /// @notice Allows contract to receive native token transfers
  receive() external payable { }

  /// @notice Fallback function to receive native token transfers
  fallback() external payable { }
}
