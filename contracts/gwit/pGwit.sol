// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";

contract pGwit is Auth {
  event Transfer(address indexed from, address indexed to, uint256 amount);

  string public constant name = "pGwit";
  string public constant symbol = "pGWIT";
  uint8 public immutable decimals = 18;

  uint256 public totalSupply;

  mapping(address => uint256) public balanceOf;

  function mint(address to, uint256 amount) external onlyRole("MINTER") {
    totalSupply += amount;

    unchecked {
      balanceOf[to] += amount;
    }

    emit Transfer(address(0), to, amount);
  }

  function burn(uint256 amount) external whenNotPaused {
    address from = msg.sender;
    balanceOf[from] -= amount;

    unchecked {
      totalSupply -= amount;
    }

    emit Transfer(from, address(0), amount);
  }
}
