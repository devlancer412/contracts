// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@rari-capital/solmate/src/tokens/ERC1155.sol";
import "./AccessControl.sol";

contract Gaff is ERC1155, AccessControl {
  //Base Uri of gem metadata
  string private _uri;

  //Fires when base uri is updated
  event UpdateUri(string uri);

  constructor(string memory uri_) {
    setUri(uri_);
  }

  function uri(uint256) public view override returns (string memory) {
    return _uri;
  }

  function mint(
    address to,
    uint256 gemId,
    uint256 amount
  ) external onlyMinter {
    _mint(to, gemId, amount, "");
  }

  function batchMint(address to, uint256[] memory amounts) external onlyMinter {
    for (uint256 gaffId = 0; gaffId < amounts.length; ) {
      _mint(to, gaffId, amounts[gaffId], "");
      unchecked {
        gaffId++;
      }
    }
  }

  function setUri(string memory newUri) public onlyOwner {
    _uri = newUri;
    emit UpdateUri(newUri);
  }
}
