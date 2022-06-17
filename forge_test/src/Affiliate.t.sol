// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Affiliate} from "contracts/affiliate/Affiliate.sol";
import {MockUsdc} from "contracts/mocks/Usdc.sol";
import {Auth} from "contracts/utils/Auth.sol";
import "./utils/BasicSetup.sol";

contract AffiliateTest is BasicSetup {
  Affiliate affiliate;
  MockUsdc usdc;

  // utils

  //  utils
  function sign(
    address sender,
    address to,
    uint64[] memory codes,
    uint256 value
  )
    public
    virtual
    returns (
      bytes32,
      bytes32,
      uint8
    )
  {
    bytes32 messageHash = keccak256(abi.encodePacked(sender, to, codes, value));

    bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSecretKey, digest);
    return (r, s, v);
  }

  // test
  function setUp() public {
    usdc = new MockUsdc();
    affiliate = new Affiliate(address(usdc), signer);

    affiliate.grantRole("DISTRIBUTOR", signer);
    usdc.mint(signer, 10000);
    vm.prank(signer);
    usdc.approve(address(affiliate), 10000);
  }

  function testRedeem() public {
    uint64[] memory codes = new uint64[](4);
    codes[0] = 1;
    codes[1] = 2;
    codes[2] = 3;
    codes[3] = 4;

    uint256 value = 650;

    (bytes32 r, bytes32 s, uint8 v) = sign(alice, alice, codes, value);

    vm.prank(alice);
    affiliate.redeemCode(alice, codes, value, Affiliate.Sig(r, s, v));
    assertEq(usdc.balanceOf(signer), 9350);
    assertEq(usdc.balanceOf(alice), 650);
  }

  function testReCall() public {
    testRedeem();
    uint64[] memory codes = new uint64[](4);
    codes[0] = 1;
    codes[1] = 2;
    codes[2] = 3;
    codes[3] = 4;

    uint256 value = 650;

    (bytes32 r, bytes32 s, uint8 v) = sign(alice, alice, codes, value);

    vm.prank(alice);
    vm.expectRevert(bytes("Affiliate:ALREADY_REDEEMED"));
    affiliate.redeemCode(alice, codes, value, Affiliate.Sig(r, s, v));
  }
}
