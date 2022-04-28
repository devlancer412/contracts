// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import {Auth} from "../utils/Auth.sol";

interface IpGwit {
  function mint(address to, uint256 amount) external;
}

contract pGwitSale is Auth {
  //pGwitSale info
  Info public info;

  //USDC address
  IERC20 public immutable usdc;

  //pGWIT address
  IpGwit public immutable pGwit;

  //Vault address
  address public immutable vault;

  //User purchased amount (user => amount)
  mapping(address => uint256) public amounts;

  struct Info {
    uint32 openingTime;
    uint32 closingTime;
    uint256 supply;
    uint256 cap;
    uint256 sold;
    uint256 price;
  }

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  //Fires when sale is set
  event Set(uint256 openingTime, uint256 closingTime, uint256 supply, uint256 cap, uint256 price);

  //Fires when pGwit purchase has been made
  event Buy(
    address indexed purchaser,
    address recipient,
    uint256 amount,
    uint256 value,
    bytes32 data
  );

  error NotOpen();
  error ExceedsSupply();
  error ExceedsCap();
  error InvalidTimeWindow();
  error InvalidOpeningTime();

  constructor(
    address usdc_,
    address pGwit_,
    address vault_
  ) {
    pGwit = IpGwit(pGwit_);
    usdc = IERC20(usdc_);
    vault = vault_;
  }

  function isOpen() public view returns (bool) {
    return block.timestamp >= info.openingTime && block.timestamp < info.closingTime;
  }

  function buy(
    address recipient,
    uint256 amount,
    uint256 deadline,
    Sig calldata sig,
    bytes32 data
  ) external whenNotPaused {
    Info memory _info = info;
    address purchaser = msg.sender;
    uint256 value = _info.price * amount;

    if (!isOpen()) revert NotOpen();
    if (_info.sold + amount > _info.supply) revert ExceedsSupply();
    if (amounts[purchaser] + amount > _info.cap) revert ExceedsCap();

    info.sold += amount;
    amounts[purchaser] += amount;

    if (deadline != 0) {
      IERC20Permit permit = IERC20Permit(address(usdc));
      permit.permit(purchaser, address(this), value, deadline, sig.v, sig.r, sig.s);
    }

    usdc.transferFrom(purchaser, vault, value);
    pGwit.mint(recipient, amount);

    emit Buy(purchaser, recipient, amount, value, data);
  }

  function set(
    uint32 openingTime,
    uint32 closingTime,
    uint256 supply,
    uint256 cap,
    uint256 price
  ) external onlyOwner {
    if (closingTime <= openingTime) revert InvalidTimeWindow();

    Info memory _info = info;

    if (!isOpen()) {
      if (openingTime < block.timestamp) revert InvalidOpeningTime();
      _info.openingTime = openingTime;
      _info.sold = 0;
    }

    _info.closingTime = closingTime;
    _info.supply = supply;
    _info.cap = cap;
    _info.price = price;

    info = _info;

    emit Set(openingTime, closingTime, supply, cap, price);
  }
}
