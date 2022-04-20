// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {RoosterMetadata} from "./RoosterMetadata.sol";
import {Auth} from "../utils/Auth.sol";

contract Rooster is ERC721, Auth, RoosterMetadata {
  //Current roosterId count
  uint256 private _roosterIdCounter = 0;

  constructor(string memory baseUri_) ERC721("Rooster", "ROOSTER") {
    setBaseUri(baseUri_);
  }

  function totalSupply() public view returns (uint256) {
    return _roosterIdCounter;
  }

  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory roosterIds
  ) external {
    for (uint256 i = 0; i < roosterIds.length; ) {
      safeTransferFrom(from, to, roosterIds[i]);
      unchecked {
        i++;
      }
    }
  }

  function mint(address to, uint256 breed) external onlyRole("MINTER") {
    uint256 roosterId = _roosterIdCounter;

    unchecked {
      _roosterIdCounter++;
    }

    _mint(to, roosterId, breed);
  }

  function batchMint(address to, uint256[] memory breeds) external onlyRole("MINTER") {
    uint256 roosterId = _roosterIdCounter;

    for (uint256 i = 0; i < breeds.length; ) {
      _mint(to, roosterId, breeds[i]);

      unchecked {
        roosterId++;
        i++;
      }
    }

    _roosterIdCounter = roosterId;
  }

  function _mint(
    address to,
    uint256 roosterId,
    uint256 breed
  ) private {
    _safeMint(to, roosterId);
    _setBreed(roosterId, breed);
  }
}
