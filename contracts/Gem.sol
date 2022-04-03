// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {GemMetadata} from "./GemMetadata.sol";
import {Auth} from "./Auth.sol";

contract Gem is ERC721, Auth, GemMetadata {
  //Current gemId count
  uint256 private _gemIdCounter = 0;

  constructor(string memory baseUri_) ERC721("Gem", "GEM") {
    setBaseUri(baseUri_);
  }

  function totalSupply() public view returns (uint256) {
    return _gemIdCounter;
  }

  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory gemIds
  ) external {
    for (uint256 i = 0; i < gemIds.length; ) {
      safeTransferFrom(from, to, gemIds[i]);
      unchecked {
        i++;
      }
    }
  }

  function mint(address to, uint256 gemType) external onlyRole("MINTER") {
    uint256 gemId = _gemIdCounter;

    unchecked {
      _gemIdCounter++;
    }

    _mint(to, gemId, gemType);
  }

  function batchMint(address to, uint256[] memory gemTypes) external onlyRole("MINTER") {
    uint256 gemId = _gemIdCounter;

    for (uint256 i = 0; i < gemTypes.length; ) {
      _mint(to, gemId, gemTypes[i]);

      unchecked {
        gemId++;
        i++;
      }
    }

    _gemIdCounter = gemId;
  }

  function _mint(
    address to,
    uint256 gemId,
    uint256 gemType
  ) private {
    _safeMint(to, gemId);
    _setGemType(gemId, gemType);
  }
}
