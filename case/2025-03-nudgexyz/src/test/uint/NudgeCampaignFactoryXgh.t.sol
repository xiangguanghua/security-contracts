// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

import { ERC20Mock } from "../mocks/ERC20Mock.sol";

import { NudgeCampaignFactory, AccessControl } from "../../campaign/NudgeCampaignFactory.sol";
import { NudgeCampaign } from "../../campaign/NudgeCampaign.sol";

contract NudgeCampaignFactoryXghTest is Test {
  // Addresses
  address treasury = makeAddr("treasury");
  address admin = makeAddr("admin");
  address operator = makeAddr("operator");
  address swapCaller = makeAddr("swapCaller");

  address ZERO_ADDRESS = address(0);
  address NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  // factory
  NudgeCampaignFactory factory;

  // deployCampaign
  uint32 holdingPeriodInSeconds = 7 days; // 7 days
  ERC20Mock targetToken;
  ERC20Mock rewardToken;
  uint256 rewardPPQ = 100; // q 这个值设置多少
  address campaignAdmin = makeAddr("campaignAdmin"); // 如果是一个合约地址呢？
  uint256 startTimestamp = block.timestamp + 1;
  address alternativeWithdrawalAddress = makeAddr("alternativeWithdrawalAddress");
  uint256 uuid = 1;

  uint256 initialRewardAmount = 1000;
  uint256 initialRewardEthAmount = 1000 ether;

  NudgeCampaign campaign;

  uint16 public FEE_BPS = 1000;

  function setUp() public {
    factory = new NudgeCampaignFactory(treasury, admin, operator, swapCaller);

    targetToken = new ERC20Mock("targetToken", "TKO");
    rewardToken = new ERC20Mock("rewardToken", "RKO");
  }

  function test_XGH_Contructor() public view {
    assertEq(factory.nudgeTreasuryAddress(), treasury);
    assertEq(factory.hasRole(factory.NUDGE_ADMIN_ROLE(), admin), true);
    assertEq(factory.hasRole(factory.NUDGE_OPERATOR_ROLE(), operator), true);
  }

  function test_XGH_DeployCampaign() public {
    address result = factory.deployCampaign(
      holdingPeriodInSeconds,
      address(targetToken),
      address(rewardToken),
      rewardPPQ,
      campaignAdmin,
      startTimestamp,
      alternativeWithdrawalAddress,
      uuid
    );
    campaign = NudgeCampaign(payable(result));

    assertEq(address(campaign.factory()), address(factory));
    assertEq(campaign.campaignId(), uuid);
    assertEq(campaign.targetScalingFactor(), 10 ** (18 - targetToken.decimals()));
    assertEq(campaign.rewardScalingFactor(), 10 ** (18 - rewardToken.decimals()));
    assertEq(campaign.hasRole(campaign.CAMPAIGN_ADMIN_ROLE(), campaignAdmin), true);
  }

  function test_XGH_ERC20_DeployAndFundCampaign() public {
    // reward token is ERC20 Token
    rewardToken.mintTo(initialRewardAmount, campaignAdmin);
    vm.prank(campaignAdmin);
    rewardToken.approve(address(factory), initialRewardAmount);

    vm.prank(campaignAdmin);
    address result = factory.deployAndFundCampaign(
      holdingPeriodInSeconds,
      address(targetToken),
      address(rewardToken),
      rewardPPQ,
      campaignAdmin,
      startTimestamp,
      alternativeWithdrawalAddress,
      0,
      uuid
    );

    campaign = NudgeCampaign(payable(result));

    assertEq(address(campaign.factory()), address(factory));
    assertEq(campaign.campaignId(), uuid);
    assertEq(campaign.targetScalingFactor(), 10 ** (18 - targetToken.decimals()));
    assertEq(campaign.rewardScalingFactor(), 10 ** (18 - rewardToken.decimals()));
    assertEq(campaign.hasRole(campaign.CAMPAIGN_ADMIN_ROLE(), campaignAdmin), true);
  }

  function test_XGH_ETH_DeployAndFundCampaign() public {
    // reward token is Ether
    // 给 campaignAdmin 设置 1000 ether 余额
    vm.deal(campaignAdmin, 0 ether);

    vm.prank(campaignAdmin);
    address result = factory.deployAndFundCampaign{ value: 0 ether }(
      holdingPeriodInSeconds,
      address(targetToken),
      NATIVE_TOKEN,
      rewardPPQ,
      campaignAdmin,
      startTimestamp,
      alternativeWithdrawalAddress,
      0 ether,
      uuid
    );

    campaign = NudgeCampaign(payable(result));

    assertEq(address(campaign.factory()), address(factory));
    assertEq(campaign.campaignId(), uuid);
    assertEq(campaign.targetScalingFactor(), 10 ** (18 - targetToken.decimals()));
    assertEq(campaign.rewardScalingFactor(), 10 ** (18 - rewardToken.decimals()));
    assertEq(campaign.hasRole(campaign.CAMPAIGN_ADMIN_ROLE(), campaignAdmin), true);
    assertEq(factory.getCampaignCount(), 1);
  }

  function test_XGH_GetCampaignAddress() public {
    address _campaign = factory.deployCampaign(
      holdingPeriodInSeconds,
      address(targetToken),
      address(rewardToken),
      rewardPPQ,
      campaignAdmin,
      startTimestamp,
      alternativeWithdrawalAddress,
      uuid
    );
    address result = factory.getCampaignAddress(
      holdingPeriodInSeconds,
      address(targetToken),
      address(rewardToken),
      rewardPPQ,
      campaignAdmin,
      startTimestamp,
      FEE_BPS,
      alternativeWithdrawalAddress,
      uuid
    );

    assertEq(result, _campaign);
  }

  function test_XGH_updateTreasuryAddress_updateFeeSetting() public {
    address newTreasury = makeAddr("newTreasury");
    uint16 newFeeBps = 20_000;

    vm.prank(admin);
    factory.updateTreasuryAddress(newTreasury);
    assertEq(factory.nudgeTreasuryAddress(), newTreasury);

    vm.prank(admin);
    factory.updateFeeSetting(newFeeBps);
    assertEq(factory.FEE_BPS(), newFeeBps);
  }

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
}
