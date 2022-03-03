// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@rari-capital/solmate/src/tokens/ERC1155.sol";
import "./AccessControl.sol";

contract GameItem is ERC1155, AccessControl {
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
    uint256 gameItemId,
    uint256 amount
  ) external onlyMinter {
    _mint(to, gameItemId, amount, "");
  }

  function batchMint(
    address to,
    uint256[] memory gameItemIds,
    uint256[] memory amounts
  ) external onlyMinter {
    _batchMint(to, gameItemIds, amounts, "");
  }

  function setUri(string memory newUri) public onlyOwner {
    _uri = newUri;
    emit UpdateUri(newUri);
  }
}
