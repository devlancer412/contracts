// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import "./GaffMetadata.sol";
import "./AccessControl.sol";

contract Gaff is ERC721, AccessControl, GaffMetadata {
  //Current gaffId count
  uint256 private _gaffIdCounter = 0;

  constructor(string memory baseUri_) ERC721("Gaff", "GAFF") {
    setBaseUri(baseUri_);
  }

  function totalSupply() public view returns (uint256) {
    return _gaffIdCounter;
  }

  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory gaffIds
  ) external {
    for (uint256 i = 0; i < gaffIds.length; ) {
      safeTransferFrom(from, to, gaffIds[i]);
      unchecked {
        i++;
      }
    }
  }

  function mint(address to, uint256 gaffType) external onlyMinter {
    uint256 gaffId = _gaffIdCounter;

    unchecked {
      _gaffIdCounter++;
    }

    _mint(to, gaffId, gaffType);
  }

  function batchMint(address to, uint256[] memory gaffTypes) external onlyMinter {
    uint256 gaffId = _gaffIdCounter;

    for (uint256 i = 0; i < gaffTypes.length; ) {
      _mint(to, gaffId, gaffTypes[i]);

      unchecked {
        gaffId++;
        i++;
      }
    }

    _gaffIdCounter = gaffId;
  }

  function _mint(
    address to,
    uint256 gaffId,
    uint256 gaffType
  ) private {
    _safeMint(to, gaffId);
    _setGaffType(gaffId, gaffType);
  }
}
