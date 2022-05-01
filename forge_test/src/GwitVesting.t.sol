// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GwitVestingSetup} from "./utils/GwitVestingSetup.sol";

contract GwitVestingTest is GwitVestingSetup {
  function setUp() public override {
    super.setUp();
  }

  function testVestedAmountBeforeTGE(uint88 aGwitAmount) public {
    vm.assume(aGwitAmount >= 1e16 && aGwitAmount <= 100_000e18);
    aGwit.mint(alice, aGwitAmount);

    set();
    assertEq(vesting.vestedAmount(alice), 0);
  }

  function testVestedAmountAfterTGE(uint88 aGwitAmount) public {
    vm.assume(aGwitAmount >= 1e16 && aGwitAmount <= 100_000e18);
    aGwit.mint(alice, aGwitAmount);

    set();
    gotoTGE();

    (, , , uint32 initialRate) = vesting.info();
    assertEq(vesting.vestedAmount(alice), (aGwitAmount * initialRate) / 10_000);
    assertEq(vesting.redeemable(alice), (aGwitAmount * initialRate) / 10_000);
  }

  function testVestedAmountAfterCliffPeriod(uint88 aGwitAmount, uint32 delta) public {
    vm.assume(aGwitAmount >= 1e16 && aGwitAmount <= 100_000e18);
    vm.assume(delta <= 15780000);
    aGwit.mint(alice, aGwitAmount);

    set();
    gotoAfterCliff();
    skip(delta);

    (uint32 startTime, , uint32 duration, uint32 initialRate) = vesting.info();
    uint256 initialAmount = (aGwitAmount * initialRate) / 10_000;
    uint32 currentTime = uint32(block.timestamp);
    assertEq(
      vesting.vestedAmount(alice),
      ((currentTime - startTime) * (aGwitAmount - initialAmount)) / duration + initialAmount
    );
  }
}
