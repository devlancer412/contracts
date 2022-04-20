// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {BasicSetup} from "./utils/BasicSetup.sol";
import {SushiswapSetup} from "./utils/SushiswapSetup.sol";
import {GWITToken} from "contracts/gwit/gwit.sol";

contract GwitTaxTest is BasicSetup {
  GWITToken gwit;
  address constant grp = address(101);
  address constant farmPool = address(102);
  address constant taxRecipient = address(201);

  function setUp() public {
    gwit = new GWITToken(1_000_000);
    gwit.init(grp, farmPool);
    gwit.setTaxAddress(taxRecipient);
  }

  function testSetTaxRate(address target, uint256 taxRate) public {
    vm.assume(taxRate <= 10000);

    gwit.setTaxRate(target, taxRate);
    assertEq(gwit.taxRate(target), taxRate);
  }

  function testCannotSetTaxRateIfNotOwner() public {
    vm.prank(alice);
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    gwit.setTaxRate(alice, 100);
  }

  function mintGwit(address to, uint256 amount) public {
    uint256 balancesSlot = 0;
    bytes32 userKey = bytes32(uint256(uint160(to)));
    bytes32 userBalanceSlot = bytes32(keccak256(abi.encodePacked(userKey, balancesSlot)));
    bytes32 value = bytes32(amount);
    vm.store(address(gwit), userBalanceSlot, value);
  }

  function testTax(
    uint256 taxRate,
    address user,
    uint256 amount
  ) public {
    vm.assume(taxRate <= 10000 && taxRate > 0);
    vm.assume(user != address(0));
    vm.assume(amount > 0 && amount <= gwit.totalSupply());

    //Set tax
    address target = address(500);
    gwit.setTaxRate(target, taxRate);

    //Mint
    mintGwit(user, amount);

    //Approve
    vm.prank(user);
    gwit.approve(target, type(uint256).max);

    //Transfer
    vm.prank(target);
    gwit.transferFrom(user, target, amount);
    assertEq(gwit.balanceOf(user), 0);
    assertEq(gwit.balanceOf(taxRecipient), (amount * taxRate) / 10_000);
    assertEq(gwit.balanceOf(target), amount - (amount * taxRate) / 10_000);
  }

  function testTaxNotFromTaxer(address user, uint256 amount) public {
    vm.assume(user != address(0));
    vm.assume(amount > 0 && amount <= gwit.totalSupply());

    address target = address(500);

    //Mint
    mintGwit(user, amount);

    //Approve
    vm.prank(user);
    gwit.approve(target, type(uint256).max);

    //Transfer
    vm.prank(target);
    gwit.transferFrom(user, target, amount);
    assertEq(gwit.balanceOf(user), 0);
    assertEq(gwit.balanceOf(target), amount);
  }
}

contract GwitSushiswapTest is SushiswapSetup {
  address constant grp = address(101);
  address constant farmPool = address(102);
  address constant taxRecipient = address(201);

  function setUp() public override {
    gwit = new GWITToken(1_000_000);
    gwit.init(grp, farmPool);
    gwit.setTaxAddress(taxRecipient);
    TAX = 1000;

    super.setUp();
  }

  function testDoesNotGetTaxedOnBuy(
    uint96 gwitToAdd,
    uint96 mockToAdd,
    uint96 amount
  ) public {
    vm.assume(gwitToAdd > 10e9 && mockToAdd > 10e9);
    vm.assume(amount > 0 && amount < gwitToAdd);

    //Add liqiduity
    addLiquidity(gwitToAdd, mockToAdd);
    setGwitBalance(taxRecipient, 0);

    //Buy GWIT
    buyGwit(alice, amount);
    assertEq(gwit.balanceOf(alice), amount);
    assertEq(gwit.balanceOf(taxRecipient), 0);
  }

  function testGetTaxedOnSell(
    uint96 gwitToAdd,
    uint96 mockToAdd,
    uint96 amount
  ) public {
    vm.assume(alice != address(0));

    vm.assume(gwitToAdd > 10e9 && mockToAdd > 10e9);
    vm.assume(amount > 0 && amount < gwitToAdd);

    //Add liqiduity
    addLiquidity(gwitToAdd, mockToAdd);
    setGwitBalance(taxRecipient, 0);

    //Sell GWIT
    sellGwit(alice, amount);
    assertEq(gwit.balanceOf(alice), 0);
    assertEq(gwit.balanceOf(taxRecipient), (amount * TAX) / 10_000);
  }
}
