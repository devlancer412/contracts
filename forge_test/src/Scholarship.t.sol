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
    const info = scholarship.info(nftId);

    assertEq(info.owner, address(this));
    assertEq(info.scholar, alice);

    scholarship.transferScholar(nftId, bob);
    const newInfo = scholarship.info(nftId);

    assertEq(newInfo.scholar, bob);

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
    const info = scholarship.info(nftIds[0]);

    assertEq(info.owner, address(this));
    assertEq(info.scholar, alice);

    addresses[0] = bob;
    scholarship.bulkTransferScholar(nftIds, addresses);
    const newInfo = scholarship.info(nftIds[0]);

    assertEq(newInfo.scholar, bob);

    scholarship.bulkRevoke(nftIds);
    vm.expectRevert(bytes("Scholarship:NOT_LENDED"));
    scholarship.info(nftIds[0]);
  }
}
