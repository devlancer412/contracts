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
  //released amount
  uint256 public released;

  //user redeemed amount
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
  }

  event Redeem(address indexed user, address indexed recipient, uint256 amount);
  event Set(uint32 start, uint32 cliff, uint32 duration, uint32 initialRate);
  event Deposit(uint256 amount, uint256 balance);
  event Withdraw(uint256 amount, uint256 balance);

  error ExceedsLimit(uint256 limit);
  error ExceedsSupply();
  error InvalidStartingTime();
  error CannotWithdrawDuringVestingPeriod();

  constructor(address pGwit_, address gwit_) {
    pGwit = IERC20(pGwit_);
    gwit = IERC20(gwit_);
  }

  function redeemable(address user) public view returns (uint256) {
    return vestedAmount(user) - redeemed[user];
  }

  function vestedAmount(address user) public view returns (uint256) {
    uint256 total = pGwit.balanceOf(user);
    uint32 currentTime = uint32(block.timestamp);
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
    if (amount > gwit.balanceOf(address(this))) revert ExceedsSupply();

    unchecked {
      released += amount;
      redeemed[user] += amount;
    }

    gwit.transfer(recipient, amount);

    emit Redeem(user, recipient, amount);
  }

  function set(
    uint32 start,
    uint32 cliff,
    uint32 duration,
    uint32 initialRate
  ) external onlyOwner {
    if (start < block.timestamp) revert InvalidStartingTime();
    info = Info(start, cliff, duration, initialRate);
    emit Set(start, cliff, duration, initialRate);
  }

  function withdraw(uint256 amount) external onlyOwner {
    Info memory _info = info;
    if (block.timestamp >= _info.start && block.timestamp <= _info.start + _info.duration) {
      revert CannotWithdrawDuringVestingPeriod();
    }
    gwit.transfer(msg.sender, amount);
    emit Withdraw(amount, gwit.balanceOf(address(this)));
  }
}
