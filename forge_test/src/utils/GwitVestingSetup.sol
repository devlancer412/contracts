// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GwitVesting} from "contracts/gwit/GwitVesting.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {Auth} from "contracts/utils/Auth.sol";
import {BasicSetup} from "./BasicSetup.sol";

contract GwitVestingSetup is BasicSetup {
  event Redeem(address indexed user, address indexed recipient, uint256 amount);
  event Set(uint32 start, uint32 cliff, uint32 duration, uint32 initialRate);
  event Withdraw(address indexed user, uint256 amount, uint256 balance);

  GwitVesting vesting;
  MockERC20 aGwit;
  MockERC20 gwit;

  function setUp() public virtual {
    aGwit = new MockERC20("AlphaGwit", "aGWIT", 18);
    gwit = new MockERC20("Gwit", "GWIT", 18);
    vesting = new GwitVesting(address(aGwit), address(gwit));

    vm.label(address(aGwit), "aGWIT");
    vm.label(address(gwit), "GWIT");
    vm.label(address(vesting), "Vesting");

    gwit.mint(address(vesting), 50_000_000e18);
  }

  function set() public virtual {
    uint32 TGE = uint32(block.timestamp) + 1 days; //in 1day
    uint32 cliff = 31560000; //12months
    uint32 duration = 47340000; //18months
    uint32 initialRate = 500; //5% TGE release

    vesting.set(TGE, cliff, duration, initialRate);
  }

  function gotoTGE(uint32 delta) public virtual {
    (uint32 startTime, uint32 cliff, , ) = vesting.info();
    vm.assume(delta < cliff);
    vm.warp(startTime + delta);
  }

  function gotoAfterCliff(uint32 delta) public virtual {
    (uint32 startTime, uint32 cliff, uint32 duration, ) = vesting.info();
    vm.assume(delta < duration - cliff);
    vm.warp(startTime + cliff + delta);
  }

  function gotoFullyVested(uint32 delta) public virtual {
    (uint32 startTime, , uint32 duration, ) = vesting.info();
    vm.assume(delta < type(uint32).max - (startTime + duration));
    vm.warp(startTime + duration + delta);
  }
}
