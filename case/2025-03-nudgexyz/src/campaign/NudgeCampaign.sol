// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// e 引用开源库
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// e 引用自己的库
import { INudgeCampaign } from "./interfaces/INudgeCampaign.sol";
import "./interfaces/INudgeCampaignFactory.sol";

/// @title NudgeCampaign
/// @notice A contract for managing Nudge campaigns with token rewards
contract NudgeCampaign is INudgeCampaign, AccessControl {
  using Math for uint256;
  using SafeERC20 for IERC20;

  /*////////////////////////////////////////////////////////////////////////
                                 常量
  ///////////////////////////////////////////////////////////////////////*/
  // Role granted to the entity which is running the campaign and managing the rewards
  bytes32 public constant CAMPAIGN_ADMIN_ROLE = keccak256("CAMPAIGN_ADMIN_ROLE");
  // q BPS是什么？这个常量是，处理定点数的吗？
  uint256 private constant BPS_DENOMINATOR = 10_000;
  // q PPQ是什么？这个常量是，处理定点数的吗？
  // qanswer 奖励因子，每十亿分之一, 用于根据参与金额（toAmount）计算奖励的系数
  uint256 private constant PPQ_DENOMINATOR = 1e15; // Denominator in parts per quadrillion
  // Special address representing the native token (ETH)
  address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /*////////////////////////////////////////////////////////////////////////
                                 不变量
  ///////////////////////////////////////////////////////////////////////*/
  //  不变量看看在哪里初始化？
  // Factory reference
  INudgeCampaignFactory public immutable factory;
  // Campaign Configuration
  uint32 public immutable holdingPeriodInSeconds;
  address public immutable targetToken;
  address public immutable rewardToken;
  uint256 public immutable rewardPPQ;
  uint256 public immutable startTimestamp;
  address public immutable alternativeWithdrawalAddress;
  // q 你是活动的唯一ID那么pid是什么？活动ID是工厂产生的吗？
  // qanswer 就是uuid
  uint256 public immutable campaignId; // Unique identifier for this campaign
  // q 这个如何使用？
  uint256 public immutable targetScalingFactor; // Scaling factors for 18 decimal normalization
  uint256 public immutable rewardScalingFactor;
  // q 这2个放到不变量的状态变量，是因为后期可能会变化。
  // q 这个是协议获取的收益吗？
  // q 这个值在什么时候确认的？
  uint16 public feeBps; // Fee parameter in basis points (1000 = 10%)
  // q 这个有什么作用？
  bool public isCampaignActive;

  /*////////////////////////////////////////////////////////////////////////
                                 状态变量
  ///////////////////////////////////////////////////////////////////////*/
  // @audit info  can be used in cross function reentrancies:
  // Campaign State
  // q 这个是干啥的
  // q 这个是什么，这个值在什么时候确认的？
  uint256 public pID;
  uint256 public pendingRewards;
  uint256 public totalReallocatedAmount;
  uint256 public accumulatedFees;
  uint256 public distributedRewards;
  // Track whether campaign was manually deactivated
  // q 这个是什么，这个值在什么时候确认的？
  bool private _manuallyDeactivated;
  // Participations
  // q 一个pid代表一个参与的人吗？
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

  /// @notice Creates a new campaign with specified parameters
  /// @param holdingPeriodInSeconds_ Duration users must hold tokens
  /// @param targetToken_ Address of token users need to hold
  /// @param rewardToken_ Address of token used for rewards
  /// @param rewardPPQ_ Amount of reward tokens earned for participating in the campaign, in parts per quadrillion
  /// @param campaignAdmin Address granted CAMPAIGN_ADMIN_ROLE
  /// @param startTimestamp_ When the campaign becomes active (0 for immediate)
  /// @param feeBps_ Nudge's fee percentage in basis points
  /// @param alternativeWithdrawalAddress_ Optional alternative address for withdrawing unallocated rewards (zero
  /// address to re-use `campaignAdmin`)
  /// @param campaignId_ Unique identifier for this campaign
  constructor(
    uint32 holdingPeriodInSeconds_,
    address targetToken_, // @audit info lacks a zero-check
    address rewardToken_,
    uint256 rewardPPQ_,
    address campaignAdmin,
    uint256 startTimestamp_,
    // q 这个字段是什么？创建工厂的时候没有使用这个字段?
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

    // q msg.sender是谁？
    factory = INudgeCampaignFactory(msg.sender);

    targetToken = targetToken_;
    rewardToken = rewardToken_;
    campaignId = campaignId_;

    // Compute scaling factors based on token decimals
    // e 如果targetToken不是 erc20地址或者eth地址那么就会报错，没有decimals方法
    // @audit info  如果target 不是erc20地址，或者不支持最新erc20标准的地址，那么IERC20Metadata(address).decimals()会报错。
    uint256 targetDecimals = targetToken_ == NATIVE_TOKEN ? 18 : IERC20Metadata(targetToken_).decimals();
    uint256 rewardDecimals = rewardToken_ == NATIVE_TOKEN ? 18 : IERC20Metadata(rewardToken_).decimals();

    // Calculate scaling factors to normalize to 18 decimals
    targetScalingFactor = 10 ** (18 - targetDecimals);
    rewardScalingFactor = 10 ** (18 - rewardDecimals);

    _grantRole(CAMPAIGN_ADMIN_ROLE, campaignAdmin);

    // @audit info 这个事件容易被操控吗
    // e block.timestamp 是提前预计生成的时间，真实事件可能会晚一点点
    startTimestamp = startTimestamp_ == 0 ? block.timestamp : startTimestamp_;
    // Campaign is active if start time is now or in the past
    // q 这个有什么用啊
    isCampaignActive = startTimestamp <= block.timestamp;

    // Initialize as not manually deactivated
    // q 这个有什么用啊
    _manuallyDeactivated = false;
    // q rewardPPQ 奖励因子是外部传入进来的吗？如何计算的？链下计算吗
    // @audit info 不需要校验码？
    rewardPPQ = rewardPPQ_;
    // q holdingPeriodInSeconds 这个字段也是前端传过来的？预计是页面选择的？能否保证安全？这里能否加校验
    holdingPeriodInSeconds = holdingPeriodInSeconds_;
    // q feeBps 这个字段也是前端传过来的？预计是页面选择的？能否保证安全？这里能否加校验
    feeBps = feeBps_;
    // @audit info 这个不需要address(0) 判断吗？
    // q alternativeWithdrawalAddress 替代提款地址,从前端传递过来的不变量地址？？？？？？，如果是address(0),或者黑客地址呢？
    alternativeWithdrawalAddress = alternativeWithdrawalAddress_;
  }

  /// @notice Calculates the total reward amount (including platform fees) based on target token amount
  /// @param toAmount Amount of target tokens to calculate rewards for
  /// @return Total reward amount including platform fees, scaled to reward token decimals
  function getRewardAmountIncludingFees(uint256 toAmount) public view returns (uint256) {
    // If both tokens have 18 decimals, no scaling needed
    if (targetScalingFactor == 1 && rewardScalingFactor == 1) {
      // q  (amount * rewardPPQ) / PPQ_DENOMINATOR
      // q rewardPPQ 不知道如何计算
      return toAmount.mulDiv(rewardPPQ, PPQ_DENOMINATOR);
    }

    uint256 scaledAmount = toAmount * targetScalingFactor;
    uint256 rewardAmountIn18Decimals = scaledAmount.mulDiv(rewardPPQ, PPQ_DENOMINATOR);
    // q 这如何发生的？
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

    // q 在哪里授权的？
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
      // q 这个校验是干嘛的？
      if (msg.value > 0) {
        revert InvalidToTokenReceived(NATIVE_TOKEN);
      }
      IERC20 tokenReceived = IERC20(toToken);
      uint256 balanceOfSender = tokenReceived.balanceOf(msg.sender);
      // q balanceBefore 为什么我要计算这个值？
      uint256 balanceBefore = getBalanceOfSelf(toToken);

      SafeERC20.safeTransferFrom(tokenReceived, msg.sender, address(this), balanceOfSender);
      // q balanceOfSender 就是amountReceived,为什么还需要减一次？
      // @audit info follow CEI
      amountReceived = getBalanceOfSelf(toToken) - balanceBefore;
    }

    // q 这难道不应该提前判断码
    if (amountReceived < toAmount) {
      revert InsufficientAmountReceived();
    }

    // q  这里又是再干啥？把钱再转回去码？
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
  // q 支持批量领取，也支持单个领取，批量领取场景是什么？
  // @audit follow-up
  // @audit info pId DOS attack
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
      // @audit follow-up
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

    // @audit info  uses timestamp for comparisons
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
  // @audit follow-up
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
