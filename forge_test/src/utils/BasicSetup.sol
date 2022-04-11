// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import "forge-std/stdlib.sol";
import {console} from "forge-std/console.sol";
import {MockContract} from "mock-contract/MockContract.sol";
import {DSTest} from "ds-test/test.sol";
import {AddressBook} from "../utils/AddressBook.sol";

abstract contract BasicSetup is DSTest, AddressBook, stdCheats {
  using stdStorage for StdStorage;
  StdStorage stdstore;

  Vm vm = Vm(HEVM_ADDRESS);

  receive() external payable {}

  fallback() external payable {}
}
