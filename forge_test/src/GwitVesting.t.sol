// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./utils/GwitVestingSetup.sol";

contract GwitVestingTest is GwitVestingSetup {
  function setUp() public override {
    super.setUp();
  }

  function testVestedAmountBeforeTGE(uint88 aGwitAmount) public {
    vm.assume(aGwitAmount <= 100_000e18);
    aGwit.mint(alice, aGwitAmount);

    set();
    assertEq(vesting.vestedAmount(alice), 0);
  }

  function testVestedAmountAfterTGE(uint88 aGwitAmount, uint32 delta) public {
    vm.assume(aGwitAmount <= 100_000e18);
    aGwit.mint(alice, aGwitAmount);

    set();
    gotoTGE(delta);

    (, , , uint32 initialRate) = vesting.info();
    assertEq(vesting.vestedAmount(alice), (aGwitAmount * initialRate) / 10_000);
    assertEq(vesting.redeemable(alice), (aGwitAmount * initialRate) / 10_000);
  }

  function testVestedAmountAfterCliffPeriod(uint88 aGwitAmount, uint32 delta) public {
    vm.assume(aGwitAmount <= 100_000e18);
    vm.assume(delta <= 15780000);
    aGwit.mint(alice, aGwitAmount);

    set();
    gotoAfterCliff(delta);

    (uint32 startTime, , uint32 duration, uint32 initialRate) = vesting.info();
    uint256 initialAmount = (aGwitAmount * initialRate) / 10_000;
    uint32 currentTime = uint32(block.timestamp);
    assertEq(
      vesting.vestedAmount(alice),
      ((currentTime - startTime) * (aGwitAmount - initialAmount)) / duration + initialAmount
    );
    assertEq(
      vesting.redeemable(alice),
      ((currentTime - startTime) * (aGwitAmount - initialAmount)) / duration + initialAmount
    );
  }

  function testVestAmountAfterFullyVested(uint88 aGwitAmount, uint32 delta) public {
    vm.assume(aGwitAmount <= 100_000e18);
    aGwit.mint(alice, aGwitAmount);

    set();
    gotoFullyVested(delta);

    assertEq(vesting.vestedAmount(alice), aGwitAmount);
    assertEq(vesting.redeemable(alice), aGwitAmount);
  }

  function testRedeemOnTGE(uint88 aGwitAmount, uint32 delta) public {
    vm.assume(aGwitAmount <= 100_000e18);
    aGwit.mint(alice, aGwitAmount);

    set();
    (, , , uint32 initialRate) = vesting.info();

    gotoTGE(delta);
    vm.prank(alice);
    vm.expectEmit(true, true, false, true);
    emit Redeem(alice, alice, (aGwitAmount * initialRate) / 10_000);
    vesting.redeem(alice, 0);

    assertEq(vesting.vestedAmount(alice), (aGwitAmount * initialRate) / 10_000);
    assertEq(vesting.redeemable(alice), 0);
    assertEq(gwit.balanceOf(alice), (aGwitAmount * initialRate) / 10_000);
    assertEq(aGwit.balanceOf(alice), aGwitAmount);
  }

  function testRedeemOnTGEAndAfterCliff(uint88 aGwitAmount, uint32 delta) public {
    vm.assume(aGwitAmount <= 100_000e18);
    aGwit.mint(alice, aGwitAmount);

    set();
    (uint32 startTime, , uint32 duration, uint32 initialRate) = vesting.info();

    gotoTGE(0);
    vm.startPrank(alice);
    vesting.redeem(alice, 0);

    gotoAfterCliff(delta);
    uint32 currentTime = uint32(block.timestamp);
    uint256 initial = (aGwitAmount * initialRate) / 10_000;
    uint256 current = ((currentTime - startTime) * (aGwitAmount - initial)) / duration;

    assertEq(vesting.redeemable(alice), current);
    vm.expectEmit(true, true, false, true);
    emit Redeem(alice, alice, current);
    vesting.redeem(alice, 0);

    assertEq(vesting.vestedAmount(alice), initial + current);
    assertEq(vesting.redeemable(alice), 0);
    assertEq(gwit.balanceOf(alice), initial + current);
    assertEq(aGwit.balanceOf(alice), aGwitAmount);
  }

  function testRedeemOnTGEAndAfterFullyVested(uint88 aGwitAmount, uint32 delta) public {
    vm.assume(aGwitAmount <= 100_000e18);
    aGwit.mint(alice, aGwitAmount);

    set();
    (, , , uint32 initialRate) = vesting.info();

    gotoTGE(10);
    vm.startPrank(alice);
    vesting.redeem(alice, 0);

    gotoFullyVested(delta);
    uint256 initial = (aGwitAmount * initialRate) / 10_000;
    uint256 current = aGwitAmount - initial;

    assertEq(vesting.redeemable(alice), current);
    vm.expectEmit(true, true, false, true);
    emit Redeem(alice, alice, current);
    vesting.redeem(alice, 0);

    assertEq(vesting.vestedAmount(alice), initial + current);
    assertEq(vesting.redeemable(alice), 0);
    assertEq(gwit.balanceOf(alice), initial + current);
    assertEq(aGwit.balanceOf(alice), aGwitAmount);
  }

  function testCannotRedeemWhenItsPaused() public {
    set();
    vesting.grantRole("PAUSER", address(this));
    vesting.pause();
    vm.expectRevert(abi.encodeWithSelector(Auth.IsPaused.selector));
    vesting.redeem(alice, 1e18);
  }

  function testCannotRedeemIfItExceedsLimit(uint88 aGwitAmount) public {
    vm.assume(aGwitAmount <= 100_000e18);
    aGwit.mint(alice, aGwitAmount);

    set();
    (, , , uint32 initialRate) = vesting.info();
    gotoTGE(0);

    vm.prank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(
        GwitVesting.ExceedsLimit.selector,
        (aGwitAmount * initialRate) / 10_000
      )
    );
    vesting.redeem(alice, aGwitAmount * initialRate + 1);
  }

  function testCannotRedeemIfItExceedsSupply(uint88 aGwitAmount) public {
    vm.assume(aGwitAmount > 1e16 && aGwitAmount <= 100_000e18);
    aGwit.mint(alice, aGwitAmount);

    set();
    (, , , uint32 initialRate) = vesting.info();

    gotoTGE(0);
    uint256 balancesSlot = 0;
    bytes32 userKey = bytes32(uint256(uint160(address(vesting))));
    bytes32 userBalanceSlot = bytes32(keccak256(abi.encodePacked(userKey, balancesSlot)));
    bytes32 value = bytes32(uint256((aGwitAmount * initialRate) / 10_000 - 1));
    vm.store(address(gwit), userBalanceSlot, value);

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(GwitVesting.ExceedsSupply.selector));
    vesting.redeem(alice, (aGwitAmount * initialRate) / 10_000);
  }

  function testWithdraw(uint128 amount) public {
    vm.assume(amount <= 50_000_000e18);
    vesting.grantRole("VAULT", address(this));

    set();

    vm.expectEmit(true, false, false, true);
    emit Withdraw(address(this), amount, 50_000_000e18 - amount);
    vesting.withdraw(amount);
    assertEq(gwit.balanceOf(address(this)), amount);
  }

  function testCannotWithdrawIfNotVault() public {
    vm.expectRevert(abi.encodeWithSelector(Auth.Unauthorized.selector, "VAULT", address(this)));
    vesting.withdraw(1e18);
  }

  function testCannotWithdrawDuringVestingPeriod(uint32 delta) public {
    set();
    vesting.grantRole("VAULT", address(this));

    (uint32 startTime, , uint32 duration, ) = vesting.info();
    vm.assume(delta < duration);
    vm.warp(startTime + delta);

    vm.expectRevert(abi.encodeWithSelector(GwitVesting.CannotWithdrawDuringVestingPeriod.selector));
    vesting.withdraw(1e18);
  }
}
