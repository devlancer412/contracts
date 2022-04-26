// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "contracts/utils/Auth.sol";
import "./utils/BasicSetup.sol";

interface AuthEvent {
  event OwnerPushed(address indexed pushedOwner);
  event OwnerPulled(address indexed previousOwner, address indexed newOwner);
  event RoleGranted(string indexed role, address indexed account, address indexed sender);
  event RoleRevoked(string indexed role, address indexed account, address indexed sender);
  event Paused(address account);
  event Unpaused(address account);
}

contract AuthTest is BasicSetup, AuthEvent {
  Auth auth;

  function setUp() public {
    vm.expectEmit(true, true, false, false);
    emit OwnerPulled(address(0), address(this));
    auth = new Auth();
  }

  function testInit() public {
    assertEq(auth.owner(), address(this));
    assertEq(auth.newOwner(), address(0));
    assertTrue(auth.paused() == false);
  }

  function testPushOwner(address user) public {
    vm.assume(user != address(0) && user != address(this));

    //Push
    vm.expectEmit(true, false, false, false);
    emit OwnerPushed(user);
    auth.pushOwner(user);

    assertEq(auth.owner(), address(this));
    assertEq(auth.newOwner(), user);
  }

  function testCannotPushOwnerIfNotOwner(address user) public {
    vm.assume(user != address(this));

    vm.prank(user);
    vm.expectRevert(abi.encodeWithSelector(Auth.Unauthorized.selector, "OWNER", user));
    auth.pushOwner(user);
  }

  function testCannotPushAddressZero() public {
    vm.expectRevert(bytes("No address(0)"));
    auth.pushOwner(address(0));
  }

  function testCannotPushCurrentOwner() public {
    vm.expectRevert(bytes("Only new owner"));
    auth.pushOwner(address(this));
  }

  function testPullOwner(address user) public {
    vm.assume(user != address(0) && user != address(this));

    //Push
    auth.pushOwner(user);

    //Pull
    vm.prank(user);
    vm.expectEmit(true, true, false, false);
    emit OwnerPulled(address(this), user);
    auth.pullOwner();

    assertEq(auth.owner(), user);
    assertEq(auth.newOwner(), user);
  }

  function testCannotPullIfNotNewOwner(address user1, address user2) public {
    vm.assume(user1 != address(0) && user2 != address(0));
    vm.assume(user1 != address(this) && user2 != address(this));
    vm.assume(user1 != user2);

    //Push
    auth.pushOwner(user1);

    //Pull
    vm.prank(user2);
    vm.expectRevert(abi.encodeWithSelector(Auth.Unauthorized.selector, "NEW_OWNER", user2));
    auth.pullOwner();
  }

  function testGrantRole(string memory role, address user) public {
    vm.assume(bytes(role).length <= 32 && bytes(role).length > 0 && user != address(0));

    vm.expectEmit(true, true, true, false);
    emit RoleGranted(role, user, address(this));
    auth.grantRole(role, user);
    assertTrue(auth.hasRole(role, user) == true);
  }

  function testCannotGrantRoleIfNotOwner(address user) public {
    vm.assume(user != address(this));

    vm.prank(user);
    vm.expectRevert(abi.encodeWithSelector(Auth.Unauthorized.selector, "OWNER", user));
    auth.grantRole("KING", user);
  }

  function testCannotGrantRoleIfNoRoleIsGiven(address user) public {
    vm.expectRevert(bytes("Role not given"));
    auth.grantRole("", user);
  }

  function testCannotGrantAddressZero() public {
    vm.expectRevert(bytes("No address(0)"));
    auth.grantRole("KING", address(0));
  }

  function testRevokeRole(string memory role, address user) public {
    vm.assume(bytes(role).length <= 32 && bytes(role).length > 0 && user != address(0));

    //Grant
    auth.grantRole(role, user);

    //Revoke
    vm.expectEmit(true, true, true, false);
    emit RoleRevoked(role, user, address(this));
    auth.revokeRole(role, user);
    assertTrue(auth.hasRole(role, user) == false);
  }

  function testCannotRevokeRoleIfNotOwner(address user) public {
    vm.assume(user != address(this));
    auth.grantRole("KING", alice);

    vm.prank(user);
    vm.expectRevert(abi.encodeWithSelector(Auth.Unauthorized.selector, "OWNER", user));
    auth.revokeRole("KING", alice);
  }

  function testCannotRevokeIfRoleNotGiven(string memory role1, string memory role2) public {
    vm.assume(bytes(role1).length <= 32 && bytes(role1).length > 0);
    vm.assume(bytes(role2).length <= 32 && bytes(role2).length > 0);
    vm.assume(keccak256(bytes(role1)) != keccak256(bytes(role2)));

    //Grant
    auth.grantRole(role1, alice);

    //Revoke
    vm.expectRevert(bytes("Role not granted"));
    auth.revokeRole(role2, alice);
  }

  function testRenounceRole(string memory role, address user) public {
    vm.assume(bytes(role).length <= 32 && bytes(role).length > 0 && user != address(0));

    //Grant
    auth.grantRole(role, user);

    //Renounce
    vm.expectEmit(true, true, true, false);
    emit RoleRevoked(role, user, user);
    vm.prank(user);
    auth.renounceRole(role);
    assertTrue(auth.hasRole(role, user) == false);
  }

  function testCannotRenounceIfRoleNotGiven(string memory role1, string memory role2) public {
    vm.assume(bytes(role1).length <= 32 && bytes(role1).length > 0);
    vm.assume(bytes(role2).length <= 32 && bytes(role2).length > 0);
    vm.assume(keccak256(bytes(role1)) != keccak256(bytes(role2)));

    //Grant
    auth.grantRole(role1, alice);

    //Renounce
    vm.expectRevert(bytes("Role not granted"));
    vm.prank(alice);
    auth.renounceRole(role2);
  }

  function grantPauserRole() public {
    grantPauserRole(address(this));
  }

  function grantPauserRole(address user) public {
    auth.grantRole("PAUSER", user);
  }

  function testPause() public {
    grantPauserRole();

    vm.expectEmit(false, false, false, true);
    emit Paused(address(this));
    auth.pause();
    assertTrue(auth.paused());
  }

  function testCannotPauseIfPaused() public {
    grantPauserRole();
    auth.pause();

    vm.expectRevert(abi.encodeWithSelector(Auth.IsPaused.selector));
    auth.pause();
  }

  function testCannotPauseIfNotPauser() public {
    vm.expectRevert(abi.encodeWithSelector(Auth.Unauthorized.selector, "PAUSER", address(this)));
    auth.pause();
  }

  function testUnpause() public {
    grantPauserRole();
    auth.pause();

    vm.expectEmit(false, false, false, true);
    emit Unpaused(address(this));
    auth.unpause();
    assertTrue(!auth.paused());
  }

  function testCannotUnpauseIfUnpaused() public {
    grantPauserRole();

    vm.expectRevert(abi.encodeWithSelector(Auth.NotPaused.selector));
    auth.unpause();
  }

  function testCannotUnpauseIfNotPauser() public {
    vm.expectRevert(abi.encodeWithSelector(Auth.Unauthorized.selector, "PAUSER", address(this)));
    auth.unpause();
  }
}
