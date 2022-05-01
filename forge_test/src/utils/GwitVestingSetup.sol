// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GwitVesting} from "contracts/gwit/GwitVesting.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {BasicSetup} from "./BasicSetup.sol";

contract GwitVestingSetup is BasicSetup {
  GwitVesting vesting;
  MockERC20 aGwit;
  MockERC20 gwit;

  function setUp() public virtual {
    aGwit = new MockERC20("AlphaGwit", "aGWIT", 18);
    gwit = new MockERC20("Gwit", "GWIT", 18);
    vesting = new GwitVesting(address(aGwit), address(gwit));

    gwit.mint(address(vesting), 50_000_000e18);
  }

  function set() public virtual {
    uint32 TGE = uint32(block.timestamp) + 1 days; //in 1day
    uint32 cliff = 31560000; //12months
    uint32 duration = 47340000; //18months
    uint32 initialRate = 500; //5% TGE release

    vesting.set(TGE, cliff, duration, initialRate);
  }

  function gotoTGE() public virtual {
    (uint32 startTime, , , ) = vesting.info();
    vm.warp(startTime);
  }

  function gotoAfterCliff() public virtual {
    (uint32 startTime, uint32 cliff, , ) = vesting.info();
    vm.warp(startTime + cliff);
  }

  function gotoFullyVested() public virtual {
    (uint32 startTime, , uint32 duration, ) = vesting.info();
    vm.warp(startTime + duration);
  }
}
