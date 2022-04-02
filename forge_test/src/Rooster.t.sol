// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Rooster} from "contracts/Rooster.sol";
import "./utils/BasicSetup.sol";

contract RoosterTest is BasicSetup {
  Rooster rooster;

  function setUp() public {
    rooster = new Rooster("");
  }

  function testInitialSupply() public {
    uint256 supply = rooster.totalSupply();
    assertEq(supply, 0);
  }

  function testMint() public {
    rooster.grantMinterRole(address(this));
    rooster.mint(alice, 3);

    uint256 supply = rooster.totalSupply();
    uint256 balance = rooster.balanceOf(alice);
    address owner = rooster.ownerOf(0);
    uint256 breed = rooster.breeds(0);

    assertEq(supply, 1);
    assertEq(balance, 1);
    assertEq(owner, alice);
    assertEq(breed, 3);
  }

  function testBatchMint() public {
    uint256[] memory breeds = new uint256[](5);
    breeds[0] = 1;
    breeds[1] = 2;
    breeds[2] = 3;
    breeds[3] = 4;
    breeds[4] = 0;

    rooster.grantMinterRole(address(this));
    rooster.batchMint(alice, breeds);

    uint256 supply = rooster.totalSupply();
    uint256 balance = rooster.balanceOf(alice);

    assertEq(supply, 5);
    assertEq(balance, 5);
  }

  function testCannotMintWithoutMinterRole() public {
    vm.expectRevert(bytes("Only minter"));
    rooster.mint(alice, 0);
  }
}
