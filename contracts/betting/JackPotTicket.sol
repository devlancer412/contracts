// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "hardhat/console.sol";

contract JackPotTicket is Auth, ERC721 {
  uint256 private _tokenCounter;
  bytes32 private _serverSeed;
  address private _treasuryAddr;
  string private _baseTokenURI;

  uint256 public openTime;
  uint256 public period;
  address public currency;
  uint256 public totalDistributeAmount;

  mapping(address => bool) private rewarded;

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  constructor() ERC721("Rooster wars betting jackpot ticket", "RWBJT") {
    _tokenCounter = 0;
    _baseTokenURI = "";
    period = 1 weeks;
    _treasuryAddr = msg.sender;
  }

  function mintTo(uint256 amount, address to) public {
    require(hasRole("MINTER", msg.sender), "JackPotTicket:CANT_MINT");

    for (uint256 i = 0; i < amount; i++) {
      _mint(to, _tokenCounter);
      _tokenCounter++;
    }
  }

  function _validateCreateParam(
    string memory serverSeed,
    address currencyAddr,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, currencyAddr, serverSeed));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("CREATOR", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function createRound(
    string memory serverSeed,
    address currencyAddr,
    Sig calldata sig
  ) public {
    require(block.timestamp > openTime, "JackPotTicket:NOT_FINISHED");
    require(_validateCreateParam(serverSeed, currencyAddr, sig), "JackPotTicket:NOT_CREATOR");

    uint256 totalAmount = IERC20(currencyAddr).balanceOf(address(this));
    require(totalAmount > 0, "JackPotTicket:INSUFFICIENT_BALANCE");

    _serverSeed = keccak256(
      abi.encodePacked(msg.sender, serverSeed, currencyAddr, block.timestamp)
    );
    openTime = block.timestamp + period;
    totalDistributeAmount = totalAmount;
    currency = currencyAddr;
    for (uint256 i = 0; i < _tokenCounter; i++) {
      rewarded[ownerOf(i)] = false;
    }
    IERC20(currency).transfer(_treasuryAddr, totalAmount / 20);
  }

  function getResult() public view returns (uint256) {
    require(balanceOf(msg.sender) > 0, "JackPotTicket:NEED_NFT");
    require(block.timestamp > openTime, "JackPotTicket:NOT_FINISHED");

    uint256 total = _tokenCounter;
    uint256[] memory results = new uint256[](total);
    address[] memory addressList = new address[](total);
    uint256 reward = 0;

    for (uint256 i = 0; i < total; i++) {
      results[i] = uint256(keccak256(abi.encodePacked(_serverSeed, i * total, ownerOf(i))));
      addressList[i] = ownerOf(i);
    }

    for (uint256 i = 0; i < total; i++) {
      for (uint256 j = i + 1; j < total; j++) {
        if (results[i] < results[j]) {
          (results[i], results[j]) = (results[j], results[i]);
          (addressList[i], addressList[j]) = (addressList[j], addressList[i]);
        }
      }
    }

    if (msg.sender == addressList[0]) {
      reward += (totalDistributeAmount * 80) / 100; // 80% to winner
    }

    for (uint256 i = 1; i < total && i < 11; i++) {
      if (msg.sender == addressList[i]) {
        reward += (totalDistributeAmount * 15) / 1000; // 1.5% to winners
      }
    }

    return reward;
  }

  function withdrawReward() public {
    uint256 reward = getResult();
    require(reward > 0, "JackPotTicket:NO_REWARD");
    require(!rewarded[msg.sender], "JackPotTicket:REWARDED");

    rewarded[msg.sender] = true;

    IERC20(currency).transfer(msg.sender, reward);
  }

  // for provably
  function getClienctSeed() public view returns (bytes32) {
    return keccak256(abi.encodePacked(_serverSeed, msg.sender));
  }

  function getServerSeed() public view returns (bytes32) {
    require(block.timestamp > openTime, "JackPotTicket:NOT_FINISHED");
    return _serverSeed;
  }

  function getAddressList() public view returns (address[] memory) {
    address[] memory addressList = new address[](_tokenCounter);
    for (uint256 i = 0; i < _tokenCounter; i++) {
      addressList[i] = ownerOf(i);
    }

    return addressList;
  }

  function getTotalReward() public view returns (string memory tokenName, uint256 amount) {
    tokenName = IERC20Metadata(currency).symbol();
    amount = totalDistributeAmount;
  }

  // setData
  function setTokenURI(string memory uri) public onlyOwner {
    _baseTokenURI = uri;
  }

  function serPeriod(uint256 _period) public onlyOwner {
    period = _period;
  }

  function setTreasuryWallet(address to) public onlyOwner {
    _treasuryAddr = to;
  }

  // NFT functions
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return _baseTokenURI;
  }
}
