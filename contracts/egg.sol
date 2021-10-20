// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "hardhat/console.sol";

contract RoosterEgg is ERC721Enumerable, ERC721Burnable, Ownable {
  using Strings for uint256;

  uint256 private _tokenIdCounter;
  string public baseURI;
  mapping(address => bool) public isOperator;

  event UpdateOperator(address user, bool isOperator);

  constructor(string memory baseURI_) ERC721("RoosterEgg", "ROOSTER_EGG") {
    baseURI = baseURI_;
    isOperator[msg.sender] = true;
    
    emit UpdateOperator(msg.sender, true);
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(bytes(baseURI).length > 0, "BaseURI not set");
    require(_exists(tokenId), "Query for nonexistent token");
    return string(abi.encodePacked(baseURI, tokenId.toString()));
  }

  function tokensOfOwner(address owner) public view returns (uint256[] memory) {
    uint256 balance = balanceOf(owner);
    uint256[] memory tokens = new uint256[](balance);
    for (uint256 i = 0; i < balance; i++) {
      tokens[i] = tokenOfOwnerByIndex(owner, i);
    }
    return tokens;
  }

  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  /* Token actions */

  function safeMint(address to, uint256 amount) external {
    address sender = _msgSender();
    require(isOperator[sender], "Invalid access");

    uint256 newtokenId = _tokenIdCounter;

    for (uint256 i = 0; i < amount; i++) {
      _safeMint(to, newtokenId);
      newtokenId++;
    }

    _tokenIdCounter = newtokenId;
  }

  /* Token settings  */

  function setBaseURI(string memory baseURI_) external onlyOwner {
    baseURI = baseURI_;
  }

  function setOperator(address user, bool isOperator_) external onlyOwner {
    isOperator[user] = isOperator_;
    emit UpdateOperator(user, isOperator_);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
