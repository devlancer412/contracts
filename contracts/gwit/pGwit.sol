// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {Auth} from "../utils/Auth.sol";

contract pGwit is ERC20, Auth {
  constructor() ERC20("pGwit", "pGWIT", 18) {}

  function mint(address to, uint256 amount) external onlyRole("MINTER") {
    _mint(to, amount);
  }
}
