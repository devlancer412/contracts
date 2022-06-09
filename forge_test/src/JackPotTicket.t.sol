// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {MockUsdc} from "contracts/mocks/Usdc.sol";
import {JackPotTicket} from "contracts/betting/JackPotTicket.sol";
import {Auth} from "contracts/utils/Auth.sol";
import {MockVRFCoordinatorV2} from "contracts/mocks/MockVRFCoordinatorV2.sol";
import "./utils/BasicSetup.sol";

contract JackPotTicketTest is BasicSetup {
  JackPotTicket jackpot;
  MockUsdc usdc;
  MockVRFCoordinatorV2 coordinator;

  // utils
  function signCreate(address to, address token)
    public
    returns (
      bytes32,
      bytes32,
      uint8
    )
  {
    bytes32 messageHash = keccak256(abi.encodePacked(to, token));
    bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSecretKey, digest);
    return (r, s, v);
  }

  function signFinish(address to)
    public
    returns (
      bytes32,
      bytes32,
      uint8
    )
  {
    bytes32 messageHash = keccak256(abi.encodePacked(to));
    bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSecretKey, digest);
    return (r, s, v);
  }

  // test
  function setUp() public {
    coordinator = new MockVRFCoordinatorV2(0, 0);
    uint64 subId = coordinator.createSubscription();
    jackpot = new JackPotTicket(subId, address(coordinator));
    usdc = new MockUsdc();

    usdc.mint(address(jackpot), 1000);
    jackpot.grantRole("SIGNER", signer);
    jackpot.grantRole("MINTER", address(this));
    jackpot.grantRole("MAINTAINER", signer);

    jackpot.mintTo(1, alice);
    jackpot.mintTo(2, bob);
    jackpot.mintTo(3, vault);
    assertEq(jackpot.balanceOf(alice), 1);
    assertEq(jackpot.balanceOf(bob), 2);
    assertEq(jackpot.balanceOf(vault), 3);

    jackpot.setTokenAllowance(address(usdc), true);
  }

  function testCreateRound() public {
    (bytes32 r, bytes32 s, uint8 v) = signCreate(signer, address(usdc));
    JackPotTicket.Sig memory sig = JackPotTicket.Sig(r, s, v);

    vm.prank(signer);
    jackpot.createRound(address(usdc), sig);
    assertEq(jackpot.getCloseTime(), block.timestamp + 3600 * 24 * 7);
  }

  function testFinishRound() public {
    testCreateRound();
    vm.warp(block.timestamp + 3600 * 24 * 7 + 1);

    (bytes32 r, bytes32 s, uint8 v) = signFinish(signer);
    JackPotTicket.Sig memory sig = JackPotTicket.Sig(r, s, v);
    vm.prank(signer);
    uint256 requestId = jackpot.finishRound(sig);

    coordinator.fulfillRandomWords(requestId, address(jackpot));

    (string memory name, uint256 amount) = jackpot.getTotalReward();
    assertEq(amount, 1000);
    assertEq(name, string("USDC"));
    assertEq(usdc.balanceOf(address(jackpot)), 950); // 5% goes to reasury wallet
  }

  function testWithdraw() public {
    testFinishRound();
    vm.prank(alice);
    jackpot.withdrawReward();
    uint256 aliceReward = usdc.balanceOf(alice);
    vm.prank(bob);
    jackpot.withdrawReward();
    uint256 bobReward = usdc.balanceOf(bob);
    vm.prank(vault);
    jackpot.withdrawReward();
    uint256 vaultReward = usdc.balanceOf(vault);

    assertEq(aliceReward + bobReward + vaultReward, 950);
  }

  function testProvably() public {
    testFinishRound();
    vm.prank(alice);
    bytes32 serverSeed = jackpot.getServerSeed();
    vm.prank(alice);
    bytes32 clientSeed = jackpot.clientSeed();
    uint256 totalReward;
    (, totalReward) = jackpot.getTotalReward();

    address[] memory addressList = jackpot.getAddressList();

    bytes32 hashed = keccak256(abi.encodePacked(serverSeed, clientSeed, addressList.length));

    hashed = keccak256(abi.encodePacked(hashed, serverSeed, clientSeed, addressList.length));
    uint256 winnerIndex = uint256(hashed) % addressList.length;

    uint256 rewardTest = 0;
    if (addressList[winnerIndex] == alice) {
      rewardTest += (totalReward * 80) / 100;
    }

    for (uint256 i = 1; i < 11; i++) {
      hashed = keccak256(abi.encodePacked(hashed, serverSeed, clientSeed, addressList.length));
      winnerIndex = uint256(hashed) % addressList.length;
      if (addressList[winnerIndex % addressList.length] == alice) {
        rewardTest += (totalReward * 15) / 1000;
      }
    }

    vm.prank(alice);
    jackpot.withdrawReward();
    assertEq(usdc.balanceOf(alice), rewardTest);
  }

  function testWithdrawTimeOver() public {
    testFinishRound();
    vm.warp(block.timestamp + 3600 * 24 * 3 + 1);

    vm.expectRevert(bytes("JackPotTicket:TIME_OVER"));
    vm.prank(alice);
    jackpot.withdrawReward();
  }
}
