// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {MockContract} from "mock-contract/MockContract.sol";
import {DSTest} from "ds-test/test.sol";
import {AddressBook} from "../utils/AddressBook.sol";

abstract contract BasicSetup is DSTest, AddressBook {
  Vm vm = Vm(HEVM_ADDRESS);

  receive() external payable {}

  fallback() external payable {}
}
