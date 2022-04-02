// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

library Strings {
  function toBytes32(string memory text) internal pure returns (bytes32) {
    return bytes32(bytes(text));
  }

  function toString(bytes32 text) internal pure returns (string memory) {
    return string(abi.encodePacked(text));
  }
}

contract RoosterAuth {
  //Address of current owner
  address public owner;
  //Address of new owner (Note: new owner must pull to be an owner)
  address public newOwner;
  //If paused or not
  uint256 private _paused;

  mapping(bytes32 => mapping(address => bool)) private roles;

  //Fires when a new owner is pushed
  event OwnerPushed(address indexed pushedOwner);
  //Fires when new owner pulled
  event OwnerPulled(address indexed previousOwner, address indexed newOwner);
  //Fires when account is granted role
  event RoleGranted(string indexed role, address indexed account, address sender);
  //Fires when accoount is revoked role
  event RoleRevoked(string indexed role, address indexed account, address sender);
  //Fires when pause is triggered by account
  event Paused(address account);
  //Fires when pause is lifted by account
  event Unpaused(address account);

  error Unauthorized(string role, address user);
  error IsPaused();
  error NotPaused();

  constructor() {
    owner = msg.sender;
    emit OwnerPulled(address(0), msg.sender);
  }

  modifier whenNotPaused() {
    if (paused()) revert IsPaused();
    _;
  }

  modifier whenPaused() {
    if (!paused()) revert NotPaused();
    _;
  }

  modifier onlyOwner() {
    if (msg.sender != owner) revert Unauthorized("OWNER", msg.sender);
    _;
  }

  modifier onlyRole(string memory role) {
    if (!hasRole(role, msg.sender)) revert Unauthorized(role, msg.sender);
    _;
  }

  function hasRole(string memory role, address account) public view returns (bool) {
    return roles[bytes32(bytes(role))][account];
  }

  function pushOwner(address account) public onlyOwner {
    require(account != address(0), "No address(0)");
    require(account != owner, "Only new owner");
    newOwner = account;
    emit OwnerPushed(account);
  }

  function pullOwner() external {
    if (msg.sender != newOwner) revert Unauthorized("NEW_OWNER", msg.sender);
    address oldOwner = owner;
    owner = msg.sender;
    emit OwnerPulled(oldOwner, msg.sender);
  }

  function grantRole(string calldata role, address account) external onlyOwner {
    require(bytes(role).length > 0, "Role not given");
    require(account != address(0), "No address(0)");
    _grantRole(role, account);
  }

  function revokeRole(string calldata role, address account) external onlyOwner {
    require(hasRole(role, account), "Role not granted");
    _revokeRole(role, account);
  }

  function renounceRole(string calldata role) external {
    require(hasRole(role, msg.sender), "Role not granted");
    _revokeRole(role, msg.sender);
  }

  function _grantRole(string calldata role, address account) private {
    if (!hasRole(role, account)) {
      bytes32 encodedRole = Strings.toBytes32(role);
      roles[encodedRole][account] = true;
      emit RoleGranted(role, account, msg.sender);
    }
  }

  function _revokeRole(string calldata role, address account) private {
    bytes32 encodedRole = Strings.toBytes32(role);
    roles[encodedRole][account] = false;
    emit RoleRevoked(role, account, msg.sender);
  }

  function paused() public view returns (bool) {
    return _paused == 1 ? true : false;
  }

  function pause() external onlyRole("PAUSER") whenNotPaused {
    _paused = 1;
    emit Paused(msg.sender);
  }

  function unpause() external onlyRole("PAUSER") whenPaused {
    _paused = 0;
    emit Unpaused(msg.sender);
  }
}
