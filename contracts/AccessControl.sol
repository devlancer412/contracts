// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract AccessControl {
  //Address of current owner
  address public owner;
  //Address of new owner (Note: new owner must pull to be an owner)
  address public newOwner;
  //Maps if user has minter role
  mapping(address => bool) public isMinter;

  //Fires when new owner is pushed
  event OwnerPushed(address indexed pushedOwner);
  //Fires when new owner pulled
  event OwnerPulled(address indexed previousOwner, address indexed newOwner);
  //Fires when minter role is granted
  event MinterRoleGranted(address indexed account);
  //Fires when minter role is revoked
  event MinterRoleRevoked(address indexed account);

  constructor() {
    owner = msg.sender;
    emit OwnerPulled(msg.sender, address(0));
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Only owner");
    _;
  }

  modifier onlyMinter() {
    require(isMinter[msg.sender], "Only minter");
    _;
  }

  function pushOwner(address account) public onlyOwner {
    require(account != address(0), "No address(0)");
    newOwner = account;
    emit OwnerPushed(account);
  }

  function pullOwner() external {
    require(msg.sender == newOwner, "Only new owner");
    address oldOwner = owner;
    owner = msg.sender;
    emit OwnerPulled(oldOwner, msg.sender);
  }

  function grantMinterRole(address account) external onlyOwner {
    require(account != address(0), "No address(0)");
    require(!isMinter[account], "Already granted");
    isMinter[account] = true;
    emit MinterRoleGranted(account);
  }

  function revokeMinterRole(address account) external onlyOwner {
    require(isMinter[account], "Not granted");
    isMinter[account] = false;
    emit MinterRoleRevoked(account);
  }
}
