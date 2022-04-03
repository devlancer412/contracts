// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Auth} from "./Auth.sol";

abstract contract GemMetadata is ERC721, Auth {
  using Strings for uint256;

  //Gem metadata base uri
  string private _baseUri;
  //Maps gem id to gem types
  mapping(uint256 => uint256) private _gemTypes;

  //Fires when base uri is updated
  event UpdateBaseUri(string baseUri);
  //Fires when gem type is set
  event GemTypeSet(uint256 indexed gemId, uint256 gemType);

  function gemTypes(uint256 gemId) public view returns (uint256) {
    require(_exists(gemId), "Query for nonexistent gem");
    return _gemTypes[gemId];
  }

  function tokenURI(uint256 gemId) public view override returns (string memory) {
    require(_exists(gemId), "Query for nonexistent gem");
    return string(abi.encodePacked(_baseUri, gemId.toString()));
  }

  function setBaseUri(string memory newUri) public onlyOwner {
    _baseUri = newUri;
    emit UpdateBaseUri(newUri);
  }

  function _setGemType(uint256 gemId, uint256 gemType) internal {
    _gemTypes[gemId] = gemType;
    emit GemTypeSet(gemId, gemType);
  }

  function _exists(uint256 tokenId) internal view returns (bool) {
    return ownerOf[tokenId] != address(0);
  }
}
