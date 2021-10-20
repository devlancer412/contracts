// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// import "hardhat/console.sol";

contract Rooster is ERC1155, ERC1155Burnable, Pausable, Ownable {
  mapping(address => bool) public isOperator;
  mapping(uint256 => BaseStats) public baseStats;

  event UpdateOperator(address user, bool isOperator);

  struct BaseStats {
    uint16 VIT;
    uint16 WATK;
    uint16 BATK;
    uint16 CATK;
    uint16 SPD;
    uint16 AGRO;
  }

  constructor() ERC1155("Rooster") {
    isOperator[msg.sender] = true;
  }

  modifier onlyOperator() {
    require(isOperator[_msgSender()], "Invalid access");
    _;
  }

  function mint(
    address account,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) public onlyOperator {
    _mint(account, id, amount, data);
  }

  function mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) public onlyOperator {
    _mintBatch(to, ids, amounts, data);
  }

  /* Admin settings  */
  function setOperator(address user, bool isOperator_) external onlyOwner {
    isOperator[user] = isOperator_;
    emit UpdateOperator(user, isOperator_);
  }

  function setURI(string memory newuri) public onlyOperator {
    _setURI(newuri);
  }

  function setBaseStats(uint256 id, uint16[] memory stats) external onlyOperator {
    baseStats[id] = BaseStats(stats[0], stats[1], stats[2], stats[3], stats[4], stats[5]);
  }

  function pause() public onlyOperator {
    _pause();
  }

  function unpause() public onlyOperator {
    _unpause();
  }

  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) internal override whenNotPaused {
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC1155) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
