// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {MockUsdc} from "contracts/mocks/Usdc.sol";
import {JackPotTicket} from "contracts/betting/JackPotTicket.sol";
import {Auth} from "contracts/utils/Auth.sol";
import "./utils/BasicSetup.sol";

contract JackPotTicketTest is BasicSetup {
  JackPotTicket jackpot;
  MockUsdc usdc;

  function setUp() public {
    jackpot = new JackPotTicket();
    usdc = new MockUsdc();
  }
}
