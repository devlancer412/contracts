// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RoosterAccessControl {
  address public owner;

  address public signer;

  address public minter;

  address public vault;

  constructor(
    address owner_,
    address signer_,
    address minter_,
    address vault_
  ) {
    owner = owner_;
    signer = signer_;
    minter = minter_;
    vault = vault_;
  }
}
