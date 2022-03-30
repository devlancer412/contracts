// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {AccessControl} from "contracts/AccessControl.sol";
import "./utils/BasicSetup.sol";

contract AccessControlTest is BasicSetup {
  AccessControl ac;

  function setUp() public {
    ac = new AccessControl();
  }

  function testInitialOwner() public {
    address owner = ac.owner();
    address newOwner = ac.newOwner();
    assertEq(owner, address(this));
    assertEq(newOwner, address(0));
  }

  function testPushOwner() public {
    ac.pushOwner(alice);

    address owner = ac.owner();
    address newOwner = ac.newOwner();
    assertEq(newOwner, alice);
    assertEq(owner, address(this));
  }

  function testPullOwner() public {
    testPushOwner();

    vm.prank(alice);
    ac.pullOwner();

    address owner = ac.owner();
    address newOwner = ac.newOwner();
    assertEq(owner, alice);
    assertEq(newOwner, alice);
  }

  function testCannotPushIfNotOwner() public {
    vm.prank(alice);
    vm.expectRevert(bytes("Only owner"));
    ac.pushOwner(alice);
  }

  function testCannotPullIfNotNewOwner() public {
    testPushOwner();

    vm.prank(bob);
    vm.expectRevert(bytes("Only new owner"));
    ac.pullOwner();
  }

  function testGrantMinterRole() public {
    ac.grantMinterRole(alice);

    assertTrue(ac.isMinter(alice) == true);
  }

  function testRevokeMinterRole() public {
    ac.grantMinterRole(alice);
    ac.revokeMinterRole(alice);
    assertTrue(ac.isMinter(alice) == false);
  }

  function testCannotGrantTwice() public {
    ac.grantMinterRole(alice);
    vm.expectRevert(bytes("Already granted"));
    ac.grantMinterRole(alice);
  }

  function testCannotRevokeIfNotGranted() public {
    vm.expectRevert(bytes("Not granted"));
    ac.revokeMinterRole(alice);
  }

  function testCannotGrantIfNotOwner() public {
    vm.prank(alice);
    vm.expectRevert(bytes("Only owner"));
    ac.grantMinterRole(alice);
  }

  function testCannotRevokeIfNotOwner() public {
    ac.grantMinterRole(alice);
    vm.prank(bob);
    vm.expectRevert(bytes("Only owner"));
    ac.revokeMinterRole(alice);
  }

  function testCannotGrantAddressZero() public {
    vm.expectRevert(bytes("No address(0)"));
    ac.grantMinterRole(address(0));
  }

  function testCannotPauseIfNotOwner() public {
    vm.prank(bob);
    vm.expectRevert(bytes("Only owner"));
    ac.pause();
  }

  function testCannotUnPauseIfNotOwner() public {
    vm.prank(bob);
    vm.expectRevert(bytes("Only owner"));
    ac.unpause();
  }
}
