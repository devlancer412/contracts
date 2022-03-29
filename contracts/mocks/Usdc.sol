// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUsdc is ERC20 {
  constructor() ERC20("USD Coin", "USDC") {
    _mint(msg.sender, 1_000_000e6);
  }

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }

  function decimals() public pure override returns (uint8) {
    return 6;
  }
}
