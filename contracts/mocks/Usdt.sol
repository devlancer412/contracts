// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {MockERC20} from "./MockERC20.sol";

contract MockUsdt is MockERC20 {
  constructor() MockERC20("Tether USD", "USDT", 6) {
    _mint(msg.sender, 1_000_000e6);
  }
}
