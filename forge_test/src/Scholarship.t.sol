// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Scholarship} from "contracts/scholarship/Scholarship.sol";
import {Rooster} from "contracts/rooster/Rooster.sol";
import {Auth} from "contracts/utils/Auth.sol";
import "./utils/BasicSetup.sol";

contract ScholarshipTest is BasicSetup {
  Rooster rooster;
  Scholarship scholarship;
  uint256 nftId;
  uint256[] nftIds;
  address[] addresses;

  function setUp() public {
    nftId = 0;
    nftIds = new uint256[](4);
    nftIds[0] = 0;
    nftIds[1] = 1;
    nftIds[2] = 2;
    nftIds[3] = 3;

    addresses = new address[](4);
    addresses[0] = bob;
    addresses[1] = bob;
    addresses[2] = bob;
    addresses[3] = bob;

    rooster = new Rooster("");
    scholarship = new Scholarship(address(rooster));

    rooster.grantRole("MINTER", address(this));
    rooster.mint(alice, 0);
    rooster.mint(alice, 1);
    rooster.mint(alice, 2);
    rooster.mint(alice, 3);

    vm.prank(alice);
    rooster.setApprovalForAll(address(scholarship), true);
  }

  function testSingleLend() public {
    vm.prank(alice);
    scholarship.lendNFT(nftId, bob);

    address owner = scholarship.getOwner(nftId);
    address scholar = scholarship.getScholar(nftId);
    assertEq(owner, alice);
    assertEq(scholar, bob);
  }

  function testSingleTransfer() public {
    vm.prank(alice);
    scholarship.lendNFT(nftId, bob);

    vm.prank(alice);
    scholarship.transferScholar(nftId, alice);
    address scholar = scholarship.getScholar(nftId);
    assertEq(scholar, alice);
  }

  function testSingleRevoke() public {
    vm.prank(alice);
    scholarship.lendNFT(nftId, bob);

    vm.prank(alice);
    scholarship.revoke(nftId);
    vm.expectRevert(bytes("Scholarship:NOT_LENDED"));
    scholarship.info(nftId);
  }

  function testBulkLend() public {
    vm.prank(alice);
    scholarship.bulkLendNFT(nftIds, addresses);
    address owner = scholarship.getOwner(nftIds[0]);
    address scholar = scholarship.getScholar(nftIds[0]);
    assertEq(owner, alice);
    assertEq(scholar, bob);
  }

  function testBulkTransfer() public {
    vm.prank(alice);
    scholarship.bulkLendNFT(nftIds, addresses);

    addresses[0] = alice;
    vm.prank(alice);
    scholarship.bulkTransferScholar(nftIds, addresses);
    address scholar = scholarship.getScholar(nftIds[0]);
    assertEq(scholar, alice);
  }

  function testBulkRevoke() public {
    vm.prank(alice);
    scholarship.bulkLendNFT(nftIds, addresses);

    vm.prank(alice);
    scholarship.bulkRevoke(nftIds);
    vm.expectRevert(bytes("Scholarship:NOT_LENDED"));
    scholarship.info(nftIds[0]);
  }
}
