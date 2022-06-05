// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {IFightBetting, FightBetting} from "contracts/betting/FightBetting.sol";
import {MockUsdc} from "contracts/mocks/Usdc.sol";
import {JackPotTicket} from "contracts/betting/JackPotTicket.sol";
import {Auth} from "contracts/utils/Auth.sol";
import "./utils/BasicSetup.sol";

contract FightBettingTest is BasicSetup {
  FightBetting fightbetting;
  MockUsdc usdc;
  JackPotTicket jackpot;
  bytes32 seedString = keccak256(abi.encodePacked("Foundry test seed"));

  //  utils
  function signCreate(
    address to,
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    uint256 minAmount,
    uint256 maxAmount,
    address tokenAddr,
    IFightBetting.Side result
  )
    public
    virtual
    returns (
      bytes32,
      bytes32,
      uint8
    )
  {
    bytes32 messageHash = keccak256(
      abi.encodePacked(
        to,
        fighter1,
        fighter2,
        startTime,
        endTime,
        minAmount,
        maxAmount,
        tokenAddr,
        bool(result == IFightBetting.Side.Fighter1)
      )
    );

    bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    console.log(uint256(messageHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSecretKey, digest);
    return (r, s, v);
  }

  function signFinish(
    address to,
    uint256 bettingId,
    IFightBetting.Side result
  )
    public
    virtual
    returns (
      bytes32,
      bytes32,
      uint8
    )
  {
    bytes32 messageHash = keccak256(
      abi.encodePacked(to, bettingId, bool(result == IFightBetting.Side.Fighter1))
    );

    bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    console.log(uint256(messageHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSecretKey, digest);
    return (r, s, v);
  }

  //  test
  function setUp() public {
    jackpot = new JackPotTicket();
    usdc = new MockUsdc();
    fightbetting = new FightBetting(address(jackpot));

    fightbetting.setTokenAllowance(address(usdc), true);

    //initialize

    usdc.mint(alice, 1000);
    assertEq(usdc.balanceOf(alice), 1000);
    usdc.mint(bob, 1000);
    assertEq(usdc.balanceOf(bob), 1000);
    usdc.mint(vault, 1000);
    assertEq(usdc.balanceOf(vault), 1000);

    jackpot.grantRole("MINTER", address(fightbetting));
    assertEq(usdc.balanceOf(address(fightbetting)), 0);
    fightbetting.setJackPotMin(1);

    fightbetting.grantRole("SIGNER", signer);
    assertTrue(fightbetting.hasRole("SIGNER", signer));
  }

  function testCreateBetting() public {
    uint256 fighter1 = 0;
    uint256 fighter2 = 1;
    uint32 startTime = uint32(block.timestamp);
    uint32 endTime = startTime + (1 hours);
    uint256 minAmount = 100;
    uint256 maxAmount = 5000;
    address tokenAddr = address(usdc);
    IFightBetting.Side result = IFightBetting.Side.Fighter1;

    (bytes32 r, bytes32 s, uint8 v) = signCreate(
      alice,
      fighter1,
      fighter2,
      startTime,
      endTime,
      minAmount,
      maxAmount,
      tokenAddr,
      result
    );

    IFightBetting.Sig memory sig = IFightBetting.Sig(r, s, v);

    vm.prank(alice);
    fightbetting.createBetting(
      fighter1,
      fighter2,
      startTime,
      endTime,
      minAmount,
      maxAmount,
      tokenAddr,
      result,
      seedString,
      sig
    );

    vm.prank(alice);
    IFightBetting.BettingState memory state = fightbetting.getBettingState(0);

    assertEq(state.bettorCount1, 0);
    assertEq(state.bettorCount2, 0);
    assertEq(state.totalAmount1, 0);
    assertEq(state.totalAmount2, 0);
  }

  function testAmount() public {
    testCreateBetting();
    vm.prank(alice);
    vm.expectRevert(bytes("FightBetting:TOO_SMALL_AMOUNT"));
    fightbetting.bettOne(0, IFightBetting.Side.Fighter1, 10);

    vm.prank(alice);
    vm.expectRevert(bytes("FightBetting:TOO_MUCH_AMOUNT"));
    fightbetting.bettOne(0, IFightBetting.Side.Fighter1, 10000);
  }

  function testBetFighter1ByAlice() public {
    testCreateBetting();
    vm.prank(alice);
    usdc.approve(address(fightbetting), 100);
    vm.prank(alice);
    fightbetting.bettOne(0, IFightBetting.Side.Fighter1, 100);

    vm.prank(alice);
    IFightBetting.BettingState memory state = fightbetting.getBettingState(0);

    assertEq(state.bettorCount1, 1);
    assertEq(state.totalAmount1, 100);
  }

  function testBetFighter1ByBob() public {
    testBetFighter1ByAlice();
    vm.prank(bob);
    usdc.approve(address(fightbetting), 200);
    vm.prank(bob);
    fightbetting.bettOne(0, IFightBetting.Side.Fighter1, 200);

    vm.prank(bob);
    IFightBetting.BettingState memory state = fightbetting.getBettingState(0);

    assertEq(state.bettorCount1, 2);
    assertEq(state.totalAmount1, 300);
  }

  function testBetFighter2ByVault() public {
    testBetFighter1ByBob();
    vm.prank(vault);
    usdc.approve(address(fightbetting), 300);
    vm.prank(vault);
    fightbetting.bettOne(0, IFightBetting.Side.Fighter2, 300);

    vm.prank(vault);
    IFightBetting.BettingState memory state = fightbetting.getBettingState(0);

    assertEq(state.bettorCount2, 1);
    assertEq(state.totalAmount2, 300);
  }

  function testOverAmount() public {
    testBetFighter2ByVault();
    vm.prank(vault);
    vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
    usdc.transfer(alice, 1000);
  }

  function testCantBetAgain() public {
    testBetFighter2ByVault();
    vm.prank(bob);
    usdc.approve(address(fightbetting), 200);
    vm.prank(bob);
    vm.expectRevert(bytes("FightBetting:ALREADY_BET"));
    fightbetting.bettOne(0, IFightBetting.Side.Fighter1, 200);
  }

  function testFinish() public {
    testBetFighter2ByVault();

    (bytes32 r, bytes32 s, uint8 v) = signFinish(alice, 0, IFightBetting.Side.Fighter1);
    IFightBetting.Sig memory sig = IFightBetting.Sig(r, s, v);
    vm.warp(block.timestamp + 3700);
    assertEq(usdc.balanceOf(address(fightbetting)), 600);
    vm.prank(alice);
    fightbetting.finishBetting(0, IFightBetting.Side.Fighter1, sig);
    assertEq(usdc.balanceOf(address(fightbetting)), 570);
  }

  function testWithdraw() public {
    testFinish();
    uint256 balanceAlice = usdc.balanceOf(alice);
    uint256 balanceBob = usdc.balanceOf(bob);

    vm.prank(alice);
    fightbetting.withdrawReward(0);
    assertEq(usdc.balanceOf(alice), balanceAlice + 176);
    vm.prank(bob);
    fightbetting.withdrawReward(0);
    assertEq(usdc.balanceOf(bob), balanceBob + 352);
    assertEq(usdc.balanceOf(address(fightbetting)), 42);
  }

  function testLuckyWithdrawReward() public {
    testWithdraw();
    vm.prank(alice);
    fightbetting.withdrawLuckyWinnerReward(0);
    vm.prank(bob);
    fightbetting.withdrawLuckyWinnerReward(0);
    assertEq(usdc.balanceOf(address(fightbetting)), 30);
  }

  function testJackPotBalance() public {
    testLuckyWithdrawReward();

    assertEq(usdc.balanceOf(address(jackpot)), 30);
  }

  function mintJackPotNFT() public {
    testJackPotBalance();

    vm.prank(alice);
    uint256 amountNFT = fightbetting.canGetJackPotNFT();
    assertEq(amountNFT, 1);

    vm.prank(alice);
    fightbetting.getJackPotNFT();
    assertEq(jackpot.balanceOf(alice), 1);
  }
}
