// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "./AccessControl.sol";

abstract contract RoosterMetadata is ERC721, AccessControl {
  using Strings for uint256;

  //Rooster metadata base uri
  string private _baseUri;
  //Maps rooster id to breed
  mapping(uint256 => uint256) private _breeds;

  //Fires when base uri is updated
  event UpdateBaseUri(string baseUri);
  //Fires when breed is set
  event BreedSet(uint256 roosterId, uint256 breed);

  function breeds(uint256 roosterId) public view returns (uint256) {
    require(_exists(roosterId), "Query for nonexistent rooster");
    return _breeds[roosterId];
  }

  function tokenURI(uint256 roosterId) public view override returns (string memory) {
    require(_exists(roosterId), "Query for nonexistent rooster");
    return string(abi.encodePacked(_baseUri, roosterId.toString()));
  }

  function setBaseUri(string memory newUri) public onlyOwner {
    _baseUri = newUri;
    emit UpdateBaseUri(newUri);
  }

  function _setBreed(uint256 roosterId, uint256 breed) internal {
    _breeds[roosterId] = breed;
    emit BreedSet(roosterId, breed);
  }

  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return ownerOf[tokenId] != address(0);
  }
}
