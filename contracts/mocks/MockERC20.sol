// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract MockERC20 is ERC20Permit {
  uint8 private immutable _decimals;

  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  ) ERC20Permit(name_) ERC20(name_, symbol_) {
    _decimals = decimals_;
  }

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }

  function burn(address account, uint256 amount) external {
    _burn(account, amount);
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }
}
