pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GWITToken is ERC20 {
  constructor(
    uint256 initialSupply,
    address grp,
    address farm_pool
  ) ERC20("GWIT", "GWIT") {
    _mint(grp, SafeMath.div(SafeMath.mul(initialSupply, 46), 100));
    _mint(farm_pool, SafeMath.div(SafeMath.mul(initialSupply, 10), 100));
    _mint(msg.sender, SafeMath.div(SafeMath.mul(initialSupply, 44), 100));
  }
}
