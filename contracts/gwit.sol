pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract GWITToken is ERC20Capped, Ownable {
  address private constant _BURN_ADDRESS = 0x0000000000000000000000000000000000001337;
  address public farm_pool;

  constructor(uint256 initialSupply, address grp) ERC20("GWIT", "GWIT") ERC20Capped(1_000_000_000) {
    ERC20Capped._mint(grp, SafeMath.div(SafeMath.mul(initialSupply, 46), 100));
  }

  function mint(address account, uint256 amount) public {
    require(msg.sender == Ownable.owner() || msg.sender == farm_pool, "unauthorized");
    ERC20Capped._mint(account, amount);
  }

  function burn(uint256 amount) public {
    transfer(_BURN_ADDRESS, amount);
  }

  function setPool(address _farm_pool) public onlyOwner {
    farm_pool = _farm_pool;
  }
}
