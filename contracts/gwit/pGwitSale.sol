// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Auth} from "../utils/Auth.sol";

interface IpGwit {
  function mint(address to, uint256 amount) external;
}

contract pGwitSale is Auth {
  //GwitSale struct
  Presale public presale;

  //USDC address
  IERC20 public immutable usdc;

  //pGWIT address
  IpGwit public immutable pGwit;

  //Vault address
  address public immutable vault;

  //User purchased amount (user => amount)
  mapping(address => uint256) public purchasedAmount;

  event PresaleSet(
    uint256 openingTime,
    uint256 closingTime,
    uint256 supply,
    uint256 cap,
    uint256 price
  );
  event Purchase(
    address indexed purchaser,
    address recipient,
    uint256 amount,
    uint256 value,
    bytes data
  );

  error NotOpen();
  error InvalidTimeWindow();
  error InvalidOpeningTime();
  error ExceedsSupply();
  error ExceedsCap();

  struct Presale {
    uint32 openingTime;
    uint32 closingTime;
    uint256 supply;
    uint256 cap;
    uint256 sold;
    uint256 price;
  }

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
    return block.timestamp >= presale.openingTime && block.timestamp < presale.closingTime;
  }

  function buy(
    address recipient,
    uint256 amount,
    bytes calldata data
  ) external whenNotPaused {
    address purchaser = msg.sender;
    uint256 value = presale.price * amount;
    Presale memory _presale = presale;

    if (!isOpen()) revert NotOpen();
    if (_presale.sold + amount > _presale.supply) revert ExceedsSupply();
    if (purchasedAmount[purchaser] + amount > _presale.cap) revert ExceedsCap();

    presale.sold += amount;
    purchasedAmount[purchaser] += amount;

    usdc.transferFrom(purchaser, vault, value);
    pGwit.mint(recipient, amount);

    emit Purchase(purchaser, recipient, amount, value, data);
  }

  function set(
    uint32 openingTime,
    uint32 closingTime,
    uint256 supply,
    uint256 cap,
    uint256 price
  ) external onlyOwner {
    if (closingTime < openingTime) revert InvalidTimeWindow();

    Presale memory _presale = presale;

    if (!isOpen()) {
      if (openingTime <= block.timestamp) revert InvalidOpeningTime();
      _presale.openingTime = openingTime;
      _presale.sold = 0;
    }

    _presale.closingTime = closingTime;
    _presale.supply = supply;
    _presale.cap = cap;
    _presale.price = price;

    presale = _presale;

    emit PresaleSet(openingTime, closingTime, supply, cap, price);
  }
}
