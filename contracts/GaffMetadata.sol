// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "./AccessControl.sol";

abstract contract GaffMetadata is ERC721, AccessControl {
  using Strings for uint256;

  //Gaff metadata base uri
  string private _baseUri;
  //Maps gaff id to gaff types
  mapping(uint256 => uint256) private _gaffTypes;

  //Fires when base uri is updated
  event UpdateBaseUri(string baseUri);
  //Fires when gaff type is set
  event GaffTypeSet(uint256 gaffId, uint256 gaffType);

  function gaffTypes(uint256 gaffId) public view returns (uint256) {
    require(_exists(gaffId), "Query for nonexistent gaff");
    return _gaffTypes[gaffId];
  }

  function tokenURI(uint256 gaffId) public view override returns (string memory) {
    require(_exists(gaffId), "Query for nonexistent gaff");
    return string(abi.encodePacked(_baseUri, gaffId.toString()));
  }

  function setBaseUri(string memory newUri) public onlyOwner {
    _baseUri = newUri;
    emit UpdateBaseUri(newUri);
  }

  function _setGaffType(uint256 gaffId, uint256 gaffType) internal {
    _gaffTypes[gaffId] = gaffType;
    emit GaffTypeSet(gaffId, gaffType);
  }

  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return ownerOf[tokenId] != address(0);
  }
}
