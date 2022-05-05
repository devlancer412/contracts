// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./utils/AlphaGwitSaleSetup.sol";

contract AlphaGwitSaleTest is AlphaGwitSaleSetup {
  function setUp() public override {
    super.setUp();
  }

  function testIsOpenWhenClosed() public {
    assertTrue(aGwitSale.isOpen() == false);
  }

  function testBuy(address user, uint256 amount) public {
    vm.assume(user != address(0));
    vm.assume(amount >= 1e18 && amount <= 100_000e18);

    set();
    gotoOpeningTime();
    mintAndApproveUsdc(user, amount);
    buy(user, amount);

    (, , , , uint256 sold, uint256 price) = aGwitSale.info();
    assertEq(usdc.balanceOf(user), 0);
    assertEq(usdc.balanceOf(vault), (amount * price) / 1e18);
    assertEq(aGwit.balanceOf(user), amount);
    assertEq(aGwit.totalSupply(), amount);
    assertEq(aGwitSale.amounts(user), amount);
    assertEq(sold, amount);
  }

  function testBuyPermit(uint248 userKey, uint256 amount) public {
    vm.assume(amount >= 1e18 && amount <= 100_000e18);
    vm.assume(userKey != 0);
    address user = vm.addr(userKey);

    set();
    gotoOpeningTime();
    (uint256 deadline, bytes32 r, bytes32 s, uint8 v) = mintAndPermitUsdc(userKey, amount);
    buyPermit(user, amount, deadline, r, s, v);

    (, , , , uint256 sold, uint256 price) = aGwitSale.info();
    assertEq(usdc.balanceOf(user), 0);
    assertEq(usdc.balanceOf(vault), (amount * price) / 1e18);
    assertEq(aGwit.balanceOf(user), amount);
    assertEq(aGwit.totalSupply(), amount);
    assertEq(aGwitSale.amounts(user), amount);
    assertEq(sold, amount);
  }

  function testBuyMulti(uint8 num, uint88 amount) public {
    vm.assume(num > 0 && num <= 100);
    vm.assume(amount >= 1e16 && amount <= 100_000e18);

    set();
    gotoOpeningTime();

    address initUser = address(99999);
    for (uint256 i = 0; i < num; i++) {
      address user = address(uint160(initUser) + uint160(i));
      mintAndApproveUsdc(user, amount);
      buy(user, amount);
      assertEq(aGwit.balanceOf(user), amount);
      assertEq(aGwitSale.amounts(user), amount);
    }

    (, , , , uint256 sold, ) = aGwitSale.info();
    assertEq(aGwit.totalSupply(), amount * num);
    assertEq(sold, amount * num);
  }

  function testCannotBuyIfPaused() public {
    set();
    aGwitSale.grantRole("PAUSER", address(this));
    aGwitSale.pause();
    vm.expectRevert(abi.encodeWithSelector(Auth.IsPaused.selector));
    buy(alice, 1e18);
  }

  function testCannotBuyBeforeSale() public {
    set();
    vm.expectRevert(abi.encodeWithSelector(AlphaGwitSale.NotOpen.selector));
    buy(alice, 1e18);
  }

  function testCannotBuyAfterSale() public {
    set();
    gotoClosingTime();
    vm.expectRevert(abi.encodeWithSelector(AlphaGwitSale.NotOpen.selector));
    buy(alice, 1e18);
  }

  function testCannotBuyIfItExceedsSupply() public {
    set();
    gotoOpeningTime();

    //Modify sold
    (, , uint256 supply, , , ) = aGwitSale.info();
    bytes32 soldSlot = bytes32(uint256(7));
    bytes32 newSold = bytes32(supply);
    vm.store(address(aGwitSale), soldSlot, newSold);

    vm.expectRevert(abi.encodeWithSelector(AlphaGwitSale.ExceedsSupply.selector));
    buy(alice, 1);
  }

  function testCannotBuyIfItExceedsCap() public {
    set();

    (, , , uint256 cap, , ) = aGwitSale.info();
    uint256 amount = cap + 1;

    gotoOpeningTime();

    vm.expectRevert(abi.encodeWithSelector(AlphaGwitSale.ExceedsCap.selector));
    buy(alice, amount);
  }

  function testCannotBuyIfItExceedsTotalCap(uint88 amount1, uint88 amount2) public {
    set();

    (, , uint256 supply, uint256 cap, , ) = aGwitSale.info();
    vm.assume(
      amount1 <= cap && uint256(amount1) + amount2 > cap && uint256(amount1) + amount2 <= supply
    );

    gotoOpeningTime();

    //Modify amounts
    uint256 amountsSlot = 9;
    bytes32 userKey = bytes32(uint256(uint160(alice)));
    bytes32 userAmountsSlot = bytes32(keccak256(abi.encodePacked(userKey, amountsSlot)));
    bytes32 value = bytes32(abi.encode(amount1));
    vm.store(address(aGwitSale), userAmountsSlot, value);

    vm.expectRevert(abi.encodeWithSelector(AlphaGwitSale.ExceedsCap.selector));
    buy(alice, amount2);
  }

  function testCannotSetIfNotOwner(address user) public {
    vm.assume(user != address(this));

    vm.prank(user);
    vm.expectRevert(abi.encodeWithSelector(Auth.Unauthorized.selector, "OWNER", user));
    aGwitSale.set(10, 20, 10e18, 1e18, 50_000);
  }
}
