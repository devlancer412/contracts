// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Scholarship} from "contracts/scholarship/Scholarship.sol";
import {Rooster} from "contracts/rooster/Rooster.sol";
import {Auth} from "contracts/utils/Auth.sol";
import "./utils/BasicSetup.sol";

contract ScholarshipTest is BasicSetup {
  Rooster rooster;
  Scholarship scholarship;

  function setUp() public {
    rooster = new Rooster("");
    scholarship = new Scholarship(address(rooster));

    rooster.grantRole("MINTER", address(this));
    rooster.mint(address(this), 0);
    rooster.mint(address(this), 1);
    rooster.mint(address(this), 2);
    rooster.mint(address(this), 3);
  }

  function testSingleLend() public {
    uint256 nftId = 0;
    scholarship.lendNFT(nftId, alice);
    address owner = scholarship.getOwner(nftId);
    address scholar = scholarship.getScholar(nftId);

    assertEq(owner, address(this));
    assertEq(scholar, alice);

    scholarship.transferScholar(nftId, bob);
    scholar = scholarship.getScholar(nftId);

    assertEq(scholar, bob);

    scholarship.revoke(nftId);
    vm.expectRevert(bytes("Scholarship:NOT_LENDED"));
    scholarship.info(nftId);
  }

  function testBulkLend() public {
    uint256 memory nftIds = [0, 1, 2, 3];
    address[] memory addresses = new address[](4);
    addresses[0] = alice;
    addresses[1] = alice;
    addresses[2] = alice;
    addresses[3] = alice;

    scholarship.bulkLendNFT(nftIds, addresses);
    address owner = scholarship.getOwner(nftIds[0]);
    address scholar = scholarship.getScholar(nftIds[0]);

    assertEq(owner, address(this));
    assertEq(scholar, alice);

    addresses[0] = bob;
    scholarship.bulkTransferScholar(nftIds, addresses);
    scholar = scholarship.getScholar(nftIds[0]);

    assertEq(scholar, bob);

    scholarship.bulkRevoke(nftIds);
    vm.expectRevert(bytes("Scholarship:NOT_LENDED"));
    scholarship.info(nftIds[0]);
  }
}
