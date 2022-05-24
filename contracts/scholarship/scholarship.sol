// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Scholarship is Ownable {
  IERC721 nft_contract;
  bool disabled;

  mapping(uint256 => address) public nft_scholar;
  mapping(uint256 => address) public nft_owner;
  mapping(address => uint256) public lended_nfts;

  event Lend(uint256 nft_id, address scholar);
  event Transfer(uint256 nft_id, address scholar);
  event Revoke(uint256 nft_id);

  constructor(address _nft_contract_address) {
    nft_contract = IERC721(_nft_contract_address);
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) public pure returns (bytes4) {
    return this.onERC721Received.selector;
  }

  modifier notDisabled() {
    require(!disabled, "Scholarship:CONTRACT_DISABLED");
    _;
  }

  modifier shouldBeOwner(uint256 nft_id) {
    require(nft_owner[nft_id] == msg.sender, "Scholarship:NOT_OWNER");
    _;
  }

  modifier lended(uint256 nft_id) {
    require(nft_owner[nft_id] != address(0), "Scholarship:NOT_LENDED");
    _;
  }

  function disable() public onlyOwner {
    disabled = true;
  }

  function enable() public onlyOwner {
    disabled = false;
  }

  function info(uint256 nft_id)
    public
    view
    lended(nft_id)
    returns (address owner, address scholar)
  {
    owner = nft_owner[nft_id];
    scholar = nft_scholar[nft_id];
  }

  function lendNFT(uint256 nft_id, address scholar) public notDisabled {
    nft_contract.safeTransferFrom(msg.sender, address(this), nft_id);

    nft_scholar[nft_id] = scholar;
    nft_owner[nft_id] = msg.sender;
    unchecked {
      lended_nfts[msg.sender] += 1;
    }

    emit Lend(nft_id, scholar);
  }

  function transferScholar(uint256 nft_id, address scholar)
    public
    notDisabled
    shouldBeOwner(nft_id)
  {
    nft_scholar[nft_id] = scholar;

    emit Transfer(nft_id, scholar);
  }

  function revoke(uint256 nft_id) public shouldBeOwner(nft_id) {
    nft_contract.safeTransferFrom(address(this), msg.sender, nft_id);
    lended_nfts[msg.sender] = lended_nfts[msg.sender] - 1;
    nft_owner[nft_id] = address(0);
    nft_scholar[nft_id] = address(0);

    emit Revoke(nft_id);
  }

  function bulkLendNFT(uint256[] calldata nft_ids, address[] calldata scholars) public {
    require(nft_ids.length == scholars.length, "Scholarship:PARAM_MISMATCH");

    for (uint256 i = 0; i < nft_ids.length; i++) {
      lendNFT(nft_ids[i], scholars[i]);
    }
  }

  function bulkTransferScholar(uint256[] calldata nft_ids, address[] calldata scholars) public {
    require(nft_ids.length == scholars.length, "Scholarship:PARAM_MISMATCH");

    for (uint256 i = 0; i < nft_ids.length; i++) {
      transferScholar(nft_ids[i], scholars[i]);
    }
  }

  function bulkRevoke(uint256[] calldata nft_ids) public {
    for (uint256 i = 0; i < nft_ids.length; i++) {
      revoke(nft_ids[i]);
    }
  }
}
