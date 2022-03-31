// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "hardhat/console.sol";

import "./GRP.sol";
import "./FarmPool.sol";

contract GWITToken is ERC20Permit, Ownable {
  address private constant _BURN_ADDRESS = 0x0000000000000000000000000000000000001337;
  address public farm_pool;
  address public grp;

  bool private _init;
  event Initialized();

  uint256 public initialSupply;

  address public tax_address;
  mapping(address => uint256) private tax_table;
  event Taxed(address from, address to, uint256 tax_amount);

  constructor(uint256 _initialSupply) ERC20Permit("GWIT") ERC20("GWIT", "GWIT") {
    initialSupply = _initialSupply * 1e18;
  }

  function init(address _grp, address _farm_pool) public onlyOwner {
    require(!_init, "already initialized");
    require(_grp != address(0) && _farm_pool != address(0), "invalid init address");
    grp = _grp;
    farm_pool = _farm_pool;

    // token distribution
    _mint(grp, (initialSupply * 46) / 100); // 46%
    _mint(farm_pool, (initialSupply * 10) / 100); // 10%
    _mint(msg.sender, (initialSupply * 44) / 100); // 44%

    _init = true;
    emit Initialized();
  }

  function burn(uint256 amount) public {
    transfer(_BURN_ADDRESS, amount);
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public override returns (bool) {
    // keeps track of the last time the msg
    console.log("TX From", from);
    console.log("TX To", to);
    console.log("TX Caller", _msgSender());
    console.log("Transfer with tax? %s", taxRate(to) != 0);
    if (taxRate(to) != 0) {
      require(amount != 0, "amount should be > 0");
      uint256 tax = calcTaxRate(to, amount);
      amount -= tax;

      // send the taxed tokens to the tax_address
      ERC20._transfer(from, tax_address, tax);
      _spendAllowance(from, to, tax);
      emit Taxed(from, to, tax);
    }

    console.log("Transferring %s", amount);
    return ERC20.transferFrom(from, to, amount);
  }

  // set the tax rate for future approvals. minium 1 = 0.01% e.g. 525 = 5.25% tax rate
  function setTaxRate(address target, uint256 _tax_Rate) public onlyOwner {
    tax_table[target] = _tax_Rate;
  }

  // set the address to where the tax gets transfered for tax
  function setTaxAddress(address _tax_address) public onlyOwner {
    tax_address = _tax_address;
  }

  function taxRate(address to) public view returns (uint256) {
    return tax_table[to];
  }

  function calcTaxRate(address to, uint256 amount) public view returns (uint256) {
    if (taxRate(to) == 0) {
      return 0;
    }
    return (amount * taxRate(to)) / 10_000;
  }
}
