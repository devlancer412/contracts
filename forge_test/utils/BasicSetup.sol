// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Vm} from "../lib/Vm.sol";
import {stdCheats} from "../lib/stdlib.sol";
import {MockContract} from "../lib/MockContract.sol";
import {DSTest} from "../lib/DSTest.sol";
import {AddressBook} from "../utils/AddressBook.sol";
import {console} from "../lib/console.sol";

abstract contract BasicSetup is DSTest, AddressBook {
  Vm vm = Vm(HEVM_ADDRESS);

  receive() external payable {}

  fallback() external payable {}
}
