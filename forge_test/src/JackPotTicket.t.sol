// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {MockUsdc} from "contracts/mocks/Usdc.sol";
import {JackPotTicket} from "contracts/betting/JackPotTicket.sol";
import {Auth} from "contracts/utils/Auth.sol";
import "./utils/BasicSetup.sol";

contract JackPotTicketTest is BasicSetup {
  JackPotTicket jackpot;
  MockUsdc usdc;
  bytes32 serverSeed = keccak256(abi.encodePacked("JackPot test"));

  // utils
  function signCreate(
    address to,
    address token,
    bytes32 seed
  )
    public
    returns (
      bytes32,
      bytes32,
      uint8
    )
  {
    bytes32 messageHash = keccak256(abi.encodePacked(to, token, seed));
    bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSecretKey, digest);
    return (r, s, v);
  }

  function signFinish(address to, bytes32 seed)
    public
    returns (
      bytes32,
      bytes32,
      uint8
    )
  {
    bytes32 messageHash = keccak256(abi.encodePacked(to, seed));
    bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSecretKey, digest);
    return (r, s, v);
  }

  // test
  function setUp() public {
    jackpot = new JackPotTicket();
    usdc = new MockUsdc();

    usdc.mint(address(jackpot), 1000);
    jackpot.grantRole("CREATOR", signer);
    jackpot.grantRole("MINTER", address(this));

    jackpot.mintTo(1, alice);
    jackpot.mintTo(2, bob);
    jackpot.mintTo(3, vault);
    assertEq(jackpot.balanceOf(alice), 1);
    assertEq(jackpot.balanceOf(bob), 2);
    assertEq(jackpot.balanceOf(vault), 3);
  }

  function testCreateRound() public {
    bytes32 hashedServerSeed = keccak256(abi.encodePacked(serverSeed, address(usdc)));
    (bytes32 r, bytes32 s, uint8 v) = signCreate(signer, address(usdc), hashedServerSeed);
    JackPotTicket.Sig memory sig = JackPotTicket.Sig(r, s, v);

    vm.prank(signer);
    jackpot.createRound(hashedServerSeed, address(usdc), sig);
    assertEq(jackpot.getOpenTime(), block.timestamp + 3600 * 24 * 7);
  }

  function testGetServerSeedBeforeFinished() public {
    testCreateRound();
    vm.prank(bob);
    vm.expectRevert(bytes("JackPotTicket:NOT_FINISHED"));
    jackpot.getServerSeed();
  }

  function testFinishRound() public {
    testCreateRound();
    vm.warp(block.timestamp + 3600 * 24 * 7 + 1);

    (bytes32 r, bytes32 s, uint8 v) = signFinish(signer, serverSeed);
    JackPotTicket.Sig memory sig = JackPotTicket.Sig(r, s, v);
    vm.prank(signer);
    jackpot.finishRound(serverSeed, sig);
    assertEq(jackpot.getServerSeed(), serverSeed);

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
    bytes32 hashedServerSeed = jackpot.getHashedServerSeed();
    vm.prank(alice);
    bytes32 clientSeed = jackpot.getClientSeed();
    uint256 totalReward;
    (, totalReward) = jackpot.getTotalReward();
    assertEq(keccak256(abi.encodePacked(serverSeed, address(usdc))), hashedServerSeed);

    address[] memory addressList = jackpot.getAddressList();

    bytes32 hashed = keccak256(abi.encodePacked(serverSeed, clientSeed, addressList.length));

    uint256 winnerIndex = uint256(hashed) % addressList.length;

    uint256 rewardTest = 0;
    if (addressList[winnerIndex] == alice) {
      rewardTest += (totalReward * 80) / 100;
    }

    for (uint256 i = 1; i < 11; i++) {
      if (addressList[(winnerIndex + i) % addressList.length] == alice) {
        rewardTest += (totalReward * 15) / 1000;
      }
    }

    vm.prank(alice);
    jackpot.withdrawReward();
    assertEq(usdc.balanceOf(alice), rewardTest);
  }
}
