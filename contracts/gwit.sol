pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "hardhat/console.sol";

import "./GRP.sol";
import "./FarmPool.sol";

contract GWITToken is ERC20, Ownable {
  address private constant _BURN_ADDRESS = 0x0000000000000000000000000000000000001337;
  address public farm_pool;
  address public grp;

  bool private _init;
  event Initialized();

  uint256 public initialSupply;

  uint256 public tax_rate;
  address public tax_address;
  mapping(address => bool) private _taxable;
  event Taxed(address from, address to, uint256 tax_ammount);

  constructor(uint256 _initialSupply) ERC20("GWIT", "GWIT") {
    initialSupply = SafeMath.mul(_initialSupply, 1_000_000_000_000_000_000);
    _init = false;
  }

  function init(address _grp, address _farm_pool) public onlyOwner {
    require(!_init, "already initialized");
    require(_grp != address(0) && _farm_pool != address(0), "invalid init address");
    grp = _grp;
    farm_pool = _farm_pool;

    // set default tax rate
    tax_rate = 5;

    // token distribution
    _mint(grp, SafeMath.div(SafeMath.mul(initialSupply, 46), 100)); // 46%
    _mint(farm_pool, SafeMath.div(SafeMath.mul(initialSupply, 10), 100)); // 10%
    _mint(msg.sender, SafeMath.div(SafeMath.mul(initialSupply, 44), 100)); // 44%

    _init = true;
    emit Initialized();
  }

  function burn(uint256 amount) public {
    transfer(_BURN_ADDRESS, amount);
  }

  // Approve on a taxed spender has the total amount deducted by a percentage specified in
  // tax_rate. Deducted funds are then transfered to the taxed address
  // function approve(address spender, uint256 amount) public override returns (bool) {
  //   if (isTaxed(spender)) {
  //     uint256 bal = balanceOf(msg.sender);
  //     require(bal >= amount, "not enough balance");

  //     uint256 tax = calcTaxRate(amount); // 5% tax
  //     amount = SafeMath.sub(amount, tax);
  //     ERC20.approve(tax_address, tax);
  //   }

  //   return ERC20.approve(spender, amount);
  // }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public override returns (bool) {
    if (isTaxed(to)) {
      uint256 tax = calcTaxRate(amount);
      amount = SafeMath.sub(amount, tax);
      ERC20._transfer(from, tax_address, tax);
      _spendAllowance(from, to, tax);
      emit Taxed(from, to, tax);
    }

    bool result = ERC20.transferFrom(from, to, amount);
    return result;
  }

  // any approvals sent to that address gets tacked on a set tax rate
  function setTaxable(address target, bool val) public onlyOwner {
    _taxable[target] = val;
  }

  // set the tax rate for future approvals. e.g. 5 = 5% tax rate
  function setTaxRate(uint256 _tax_Rate) public onlyOwner {
    tax_rate = _tax_Rate;
  }

  // set the address to where the tax gets transfered for tax
  function setTaxAddress(address _tax_address) public onlyOwner {
    tax_address = _tax_address;
  }

  function isTaxed(address spender) public view returns (bool) {
    return _taxable[spender];
  }

  function calcTaxRate(uint256 amount) public view returns (uint256) {
    if (tax_rate == 0) {
      return 0;
    }
    return SafeMath.div(SafeMath.mul(amount, tax_rate), 100); // 5% tax
  }
}
