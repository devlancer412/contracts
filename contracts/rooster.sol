// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import "./RoosterMetadata.sol";
import "./AccessControl.sol";
import "hardhat/console.sol";

contract Rooster is ERC721, AccessControl, RoosterMetadata {
  //Current roosterId count
  uint256 private _roosterIdCounter = 0;
  //Rooster hard cap
  uint256 public constant cap = 150_000;

  constructor(string memory baseUri_) ERC721("Rooster", "ROOSTER") {
    setBaseUri(baseUri_);
  }

  function totalSupply() public view returns (uint256) {
    return _roosterIdCounter;
  }

  function mint(address to, Breed breed) external onlyMinter {
    require(totalSupply() + 1 <= cap, "cap exceeded");
    uint256 roosterId = _roosterIdCounter++;
    _mint(to, roosterId, breed);
  }

  function mintBatch(address to, Breed[] memory breeds) external onlyMinter {
    require(totalSupply() + breeds.length <= cap, "cap exceeded");

    uint256 roosterId = _roosterIdCounter;
    for (uint256 i = 0; i < breeds.length; i++) {
      _mint(to, roosterId, breeds[i]);
      roosterId++;
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

  function _baseURI() internal view override(ERC721, RoosterMetadata) returns (string memory) {
    return RoosterMetadata._baseURI();
  }
}
