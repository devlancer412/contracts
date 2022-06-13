// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {MockERC20} from "./MockERC20.sol";

contract MockUsdc is MockERC20 {
  constructor() MockERC20("USD Coin", "USDC", 6) {
    _mint(msg.sender, 1_000_000e6);
  }
}
