// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test, StdInvariant, console2 } from "forge-std/Test.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { NudgeCampaignFactory } from "../../campaign/NudgeCampaignFactory.sol";
import { NudgeCampaign } from "../../campaign/NudgeCampaign.sol";
import { Handler } from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {
  /*//////////////////////////////
              工厂参数
  ////////////////////////////// */
  address treasury = makeAddr("treasury");
  address admin = makeAddr("admin");
  address operator = makeAddr("operator");
  address swapCaller = makeAddr("swapCaller");

  // factory
  NudgeCampaignFactory factory;

  Handler handler;

  function setUp() public {
    factory = new NudgeCampaignFactory(treasury, admin, operator, swapCaller);
    handler = new Handler(factory);

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = Handler.handleReallocation.selector;

    targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    targetContract(address(handler));
  }

  function invariant_solvency() public view {
    assertGe(
      handler.rewardToken().balanceOf(address(handler.campaign())),
      handler.campaign().pendingRewards() + handler.campaign().accumulatedFees()
    );
  }

  function invariant_userRewardsAndFees() public view {
    console2.log("left :", handler.campaign().pendingRewards() + handler.campaign().accumulatedFees());
    console2.log("right:", handler.campaign().getRewardAmountIncludingFees(handler.campaign().totalReallocatedAmount()));
    assertEq(
      handler.campaign().pendingRewards() + handler.campaign().accumulatedFees(),
      handler.campaign().getRewardAmountIncludingFees(handler.campaign().totalReallocatedAmount())
    );
  }
}
