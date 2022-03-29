// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Vm} from "../lib/Vm.sol";
import {DSTest} from "../lib/DSTest.sol";

abstract contract AddressBook is DSTest {
  Vm private vm = Vm(HEVM_ADDRESS);

  address deployer = address(1);
  address minter = address(2);
  address alice = address(3);
  address bob = address(4);
  address vault = address(5);
  uint256 signerSecretKey = 711;
  address signer = vm.addr(signerSecretKey);
}
