// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import "./utils/FightBettingSetup.sol";

contract FightBettingTest is FightBettingSetup {
  function setUp() public override {
    super.setUp();
  }

  function createBetting() public {
    uint32 startTime = 1000;
    uint32 endTime = startTime + 3600;
    uint256 minAmount = 5 * 10**17;
    uint256 maxAmount = 5 * 10**18;

    vm.warp(startTime);
    (bytes32 r, bytes32 s, uint8 v) = sign(alice, 0, 1, startTime, endTime, minAmount, maxAmount);
    FightBetting.Sig memory sig = FightBetting.Sig(r, s, v);

    vm.prank(alice);
    bettingContract.createBetting(0, 1, startTime, endTime, minAmount, maxAmount, sig);

    FightBetting.BettingData memory state = bettingContract.bettingState(0);
    assertEq(state.totalPrice1, 0);
    assertEq(state.totalPrice2, 0);
    assertEq(state.bettorCount1, 0);
    assertEq(state.bettorCount2, 0);
  }

  function betToFirstWidthAlice() public {
    vm.prank(alice);
  }
}
