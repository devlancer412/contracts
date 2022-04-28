// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import {Auth} from "../utils/Auth.sol";

interface IpGwit is IERC20, IERC20Permit {}

contract GwitRedeemer is Auth {
  IpGwit public immutable pGwit;
  IERC20 public immutable gwit;
  Info public info;

  mapping(address => uint32) public lastRedeemed;

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  struct Info {
    uint32 start;
    uint32 duration;
    uint256 supply;
    uint256 released;
  }

  event Redeem(address indexed user, address indexed recipient, uint256 amount);
  event Set(uint256 start, uint256 duration, uint256 supply);

  constructor(address pGwit_, address gwit_) {
    pGwit = IpGwit(pGwit_);
    gwit = IERC20(gwit_);
  }

  function redeemable(address user) public view returns (uint256) {
    uint32 start = lastRedeemed[user] > 0 ? lastRedeemed[user] : info.start;
    if (start < block.timestamp) {
      return 0;
    } else {
      return ((block.timestamp - start) * pGwit.balanceOf(user)) / info.duration;
    }
  }

  function redeem(
    address recipient,
    uint256 amount,
    uint256 deadline,
    Sig calldata sig
  ) external {
    address user = msg.sender;
    uint256 redeemableAmount = redeemable(user);
    if (amount > 0) {
      require(amount <= redeemableAmount, "Exceeds limit");
    } else {
      amount = redeemableAmount;
    }

    lastRedeemed[user] = uint32(block.timestamp);
    unchecked {
      info.released += amount;
    }

    if (deadline > 0) {
      pGwit.permit(user, address(this), amount, deadline, sig.v, sig.r, sig.s);
    }

    pGwit.transferFrom(user, address(this), amount);
    gwit.transfer(recipient, amount);

    emit Redeem(user, recipient, amount);
  }

  function set(
    uint32 start,
    uint32 duration,
    uint256 supply
  ) external onlyOwner {
    Info memory _info = info;

    _info.start = start;
    _info.duration = duration;
    _info.supply = supply;
    info = _info;

    emit Set(start, duration, supply);
  }
}
