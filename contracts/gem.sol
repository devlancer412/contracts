// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./AccessControl.sol";
import "hardhat/console.sol";

contract Gem is ERC1155, AccessControl {
  constructor(string memory uri) ERC1155(uri) {}

  function mint(
    address to,
    uint256 id,
    uint256 amount
  ) external onlyMinter {
    _mint(to, id, amount, "");
  }

  function mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external onlyMinter {
    _mintBatch(to, ids, amounts, "");
  }

  function mintByIds(
    address to,
    uint256[] memory gemIds
  ) external onlyMinter {
    for(uint256 i = 0; i < gemIds.length; i++){
      _mint(to, gemIds[i], 1, "");
    }
  }

  function setURI(string memory newuri) external onlyOwner {
    _setURI(newuri);
  }
}
