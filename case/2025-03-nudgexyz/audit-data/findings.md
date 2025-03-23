### [I-1] `INudgeCampaign::getBalanceOfSelf` is not used and should be removed

**Proof of Concept:** `INudgeCampaign::getBalanceOfSelf` After the redundant code is removed, the system operation is not affected. The proof code is as follows：

```diff
   ...
-  function getBalanceOfSelf(address token) external view returns (uint256);
   function claimableRewardAmount() external view returns (uint256);
   function getRewardAmountIncludingFees(uint256 toAmount) external view returns (uint256);
   ...
```

Run `forge build` with the comment and the result is as follows:

```javascript
forge build 
[⠒] Compiling...
[⠢] Compiling 10 files with Solc 0.8.28
[⠆] Solc 0.8.28 finished in 3.97s
Compiler run successful!
```

**Recommended Mitigation:** It is recommended to remove redundant code

```diff
   ...
-  function getBalanceOfSelf(address token) external view returns (uint256);
   function claimableRewardAmount() external view returns (uint256);
   function getRewardAmountIncludingFees(uint256 toAmount) external view returns (uint256);
   ...
```

### [I-2] Batch changes to the state variable in the for loop result in a low Gas error

**Description:** In the `NudgeCampaignFactory::pauseCampaigns` and `NudgeCampaignFactory::unpauseCampaigns` functions, the value of the state variable is modified and read in batches, and if the campaigns array is relatively large, it will cause the problem of insufficient Gas fees

```javascript
   /// @notice Pauses multiple campaigns
  /// @param campaigns Array of campaign addresses to pause
  /// @dev Only callable by NUDGE_ADMIN_ROLE
  function pauseCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_ADMIN_ROLE) {
@>  for (uint256 i = 0; i < campaigns.length; i++) {
      if (!isCampaign[campaigns[i]]) revert InvalidCampaign();
      if (isCampaignPaused[campaigns[i]]) revert CampaignAlreadyPaused();
@>      isCampaignPaused[campaigns[i]] = true;
    }
    emit CampaignsPaused(campaigns);
  }

  /// @notice Unpauses multiple campaigns
  /// @param campaigns Array of campaign addresses to unpause
  /// @dev Only callable by NUDGE_ADMIN_ROLE
  function unpauseCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_ADMIN_ROLE) {
@>  for (uint256 i = 0; i < campaigns.length; i++) {
      if (!isCampaign[campaigns[i]]) revert InvalidCampaign();
      if (!isCampaignPaused[campaigns[i]]) revert CampaignNotPaused();
@>      isCampaignPaused[campaigns[i]] = false;
    }
    emit CampaignsUnpaused(campaigns);
  }
}
```
**Impact:** Failed to modify compaign

**Proof of Concept:** 

<details>
<summary>Proof Of Code</summary>

```javascript
function test_PauseCampaigns() public {
    // 设置 gas price 为 1 wei
    vm.txGasPrice(1);
    uint256 campaignNum = 500;
    address[] memory campaigns = new address[](campaignNum);
    for (uint256 i = 0; i < campaignNum; i++) {
      campaigns[i] = factory.deployCampaign(
        holdingPeriodInSeconds,
        address(targetToken),
        address(rewardToken),
        rewardPPQ,
        campaignAdmin,
        startTimestamp,
        alternativeWithdrawalAddress,
        uuid + i
      );
    }

    uint256 gasStart = gasleft();
    vm.prank(admin);
    factory.pauseCampaigns(campaigns);
    uint256 gasEnd = gasleft();
    uint256 gasCost = (gasStart - gasEnd) * tx.gasprice; // 计算 gas 成本
    console2.log("Gas cost of the 100 campaigns : ", gasCost);
  }
        // Logs:
        //     ...
        //    │   └─ ← [OutOfGas] EvmError: OutOfGas
        //    └─ ← [Revert] EvmError: Revert
       //   Suite result: FAILED. 0 passed; 1 failed; 0 skipped; finished in 80.05ms (79.10ms CPU time)
```
</details>

**Recommended Mitigation:** There are a few recommended mitigations.

1.It is recommended that the front-end call the modification method in batches
2.Supports individual activity pauses

Alternatively, you could use [OpenZeppelin's `EnumerableSet` library](https://docs.openzeppelin.com/contracts/4.x/api/utils#EnumerableSet).



### [I-3] In the `NudgeCampaign::handleReallocation` function, Why transfer amountReceived to userAddresses?

**Description:**  According to the project introduction, participants invest the targetToken amount into the compaign. However, in the `NudgeCampaign::handleReallocation` function, the targetToken amountReceived deposited by the user is returned to the userAddress, which is very strange.

I don’t know if I misunderstood the requirements or the code was implemented incorrectly.

```javascript
                    ...
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
@>    _transfer(toToken, userAddress, amountReceived);

    totalReallocatedAmount += amountReceived;

    uint256 rewardAmountIncludingFees = getRewardAmountIncludingFees(amountReceived);

    uint256 rewardsAvailable = claimableRewardAmount();
    if (rewardAmountIncludingFees > rewardsAvailable) {
      revert NotEnoughRewardsAvailable();
    }

                     ...
```

**Recommended Mitigation:** Added detailed code comments or Added project usage flowchart.

