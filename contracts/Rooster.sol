// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import "./RoosterMetadata.sol";
import "./AccessControl.sol";

contract Rooster is ERC721, AccessControl, RoosterMetadata {
  //Current roosterId count
  uint256 private _roosterIdCounter = 0;

  constructor(string memory baseUri_) ERC721("Rooster", "ROOSTER") {
    setBaseUri(baseUri_);
  }

  function totalSupply() public view returns (uint256) {
    return _roosterIdCounter;
  }

  function mint(address to, Breed breed) external onlyMinter {
    uint256 roosterId = _roosterIdCounter;

    unchecked {
      _roosterIdCounter++;
    }

    _mint(to, roosterId, breed);
  }

  function batchMint(address to, Breed[] memory breeds) external onlyMinter {
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
    Breed breed
  ) private {
    _safeMint(to, roosterId);
    _setBreed(roosterId, breed);
  }
}
