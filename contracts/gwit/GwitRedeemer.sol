// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Auth} from "../utils/Auth.sol";

contract GwitVesting is Auth {
  //Gwit vesting info
  Info public info;
  //pGWIT address
  IERC20 public immutable pGwit;
  //GWIT address
  IERC20 public immutable gwit;
  //User redeemed amount
  mapping(address => uint256) public redeemed;

  struct Info {
    //start time of the vesting period
    uint32 start;
    //cliff period in seconds
    uint32 cliff;
    //duration of vesting period
    uint32 duration;
    //initial release at start time in hundreds ( 500 = 5% )
    uint32 initialRate;
    //total supply of tokens to be released
    uint256 supply;
    //amount of tokens released
    uint256 released;
  }

  event Redeem(address indexed user, address indexed recipient, uint256 amount);
  event Set(uint256 start, uint256 duration, uint256 supply);

  error ExceedsLimit(uint256 limit);
  error ExceedsSupply();

  constructor(address pGwit_, address gwit_) {
    pGwit = IERC20(pGwit_);
    gwit = IERC20(gwit_);
  }

  function redeemable(address user) public view returns (uint256) {
    return vestedAmount(user) - redeemed[user];
  }

  function vestedAmount(address user) public view returns (uint256) {
    uint256 total = pGwit.balanceOf(user);
    uint256 currentTime = block.timestamp;
    Info memory _info = info;

    if (currentTime < _info.start) {
      return 0;
    } else if (currentTime < _info.start + _info.duration) {
      uint256 initial = (total * _info.initialRate) / 10_000;
      if (currentTime < _info.start + _info.cliff) {
        return initial;
      } else {
        return ((currentTime - _info.start) * (total - initial)) / _info.duration + initial;
      }
    } else {
      return total;
    }
  }

  function redeem(address recipient, uint256 amount) external whenNotPaused {
    address user = msg.sender;
    uint256 maxAmount = redeemable(user);

    if (amount > 0) {
      if (amount > maxAmount) revert ExceedsLimit(maxAmount);
    } else {
      amount = maxAmount;
    }
    if (amount > info.supply - info.released) revert ExceedsSupply();

    unchecked {
      info.released += amount;
      redeemed[user] += amount;
    }

    gwit.transfer(recipient, amount);

    emit Redeem(user, recipient, amount);
  }

  function set(
    uint32 start,
    uint32 cliff,
    uint32 duration,
    uint32 initialRate,
    uint256 supply
  ) external onlyOwner {
    Info memory _info = info;

    _info.start = start;
    _info.cliff = cliff;
    _info.duration = duration;
    _info.supply = supply;
    _info.initialRate = initialRate;
    info = _info;

    emit Set(start, duration, supply);
  }
}
