// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { NudgeCampaign } from "../../campaign/NudgeCampaign.sol";
import { NudgeCampaignFactory } from "../../campaign/NudgeCampaignFactory.sol";

contract Handler is Test {
  /*//////////////////////////////
              活动参数
  ////////////////////////////// */
  uint32 holdingPeriodInSeconds = 60 * 60 * 24 * 7; // 7 days
  ERC20Mock public targetToken;
  ERC20Mock public rewardToken;
  uint256 rewardPPQ = 2e13;
  address campaignAdmin = makeAddr("campaignAdmin");
  uint256 startTimestamp = block.timestamp + 10 days;
  address alternativeWithdrawalAddress = makeAddr("alternativeWithdrawalAddress");
  uint256 initialRewardAmount = 100_000e18;
  uint256 uuid = 1;

  address ZERO_ADDRESS = address(0);
  address NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  NudgeCampaignFactory public factory;
  NudgeCampaign public campaign;

  address swapCaller = makeAddr("swapCaller");
  address alice = makeAddr("alice");

  constructor(NudgeCampaignFactory _factory) {
    factory = _factory;
    targetToken = new ERC20Mock("targetToken", "TKO");
    rewardToken = new ERC20Mock("rewardToken", "RKO");

    rewardToken.mintTo(initialRewardAmount, campaignAdmin);
    vm.prank(campaignAdmin);
    rewardToken.approve(address(factory), initialRewardAmount);

    vm.prank(campaignAdmin);
    address campaignAddr = factory.deployAndFundCampaign(
      holdingPeriodInSeconds,
      address(targetToken),
      address(rewardToken),
      rewardPPQ,
      campaignAdmin,
      0,
      alternativeWithdrawalAddress,
      initialRewardAmount,
      uuid
    );

    campaign = NudgeCampaign(payable(campaignAddr));
  }

  function handleReallocation(uint256 toAmount) public {
    toAmount = bound(toAmount, 0, initialRewardAmount);
    targetToken.mintTo(toAmount, swapCaller);

    vm.prank(swapCaller);
    targetToken.approve(address(campaign), toAmount);

    vm.prank(swapCaller);
    campaign.handleReallocation(uuid, alice, address(targetToken), toAmount, "");
  }
}
