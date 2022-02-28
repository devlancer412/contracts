// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./AccessControl.sol";

abstract contract RoosterMetadata is ERC721, AccessControl {
  //Rooster metadata base uri
  string private _baseUri;
  //Maps rooster id to breed
  mapping(uint256 => Breed) private _breeds;
  //Maps breed to base stats
  mapping(Breed => BaseStats) public baseStats;

  //Fires when base stats is updated
  event UpdateBaseStats(Breed breed, BaseStats baseStats);
  //Fires when base uri is updated
  event UpdateBaseUri(string baseUri);
  //Fires when breed is set
  event BreedSet(uint256 roosterId, Breed breed);

  enum Breed {
    Swansons,
    Kelians,
    Rotundan,
    Hatch,
    Greybacks,
    Claira,
    Redheart,
    Pylia,
    Jonians,
    Henis
  }

  struct BaseStats {
    uint32 VIT;
    uint32 WATK;
    uint32 BATK;
    uint32 CATK;
    uint32 SPD;
    uint32 AGRO;
  }

  function breeds(uint256 roosterId) public view returns (Breed) {
    require(_exists(roosterId), "Query for nonexistent rooster");
    return _breeds[roosterId];
  }

  function setBaseStats(Breed breed, BaseStats memory newStats) external onlyOwner {
    baseStats[breed] = newStats;
    emit UpdateBaseStats(breed, newStats);
  }

  function setBaseUri(string memory newUri) public onlyOwner {
    _baseUri = newUri;
    emit UpdateBaseUri(newUri);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseUri;
  }

  function _setBreed(uint256 roosterId, Breed breed) internal {
    _breeds[roosterId] = breed;
    emit BreedSet(roosterId, breed);
  }
}
