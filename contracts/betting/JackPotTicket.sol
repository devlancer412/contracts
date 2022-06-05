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
  uint256 public totalDistributeAmount;
  bytes32 public hashedServerSeed;
  bytes32 public clientSeed;
  address public token;

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
    openTime = block.timestamp;
  }

  modifier hasTicket() {
    require(balanceOf(msg.sender) > 0, "JackPotTicket:NO_TICKET");
    _;
  }

  function mintTo(uint256 amount, address to) public {
    require(hasRole("MINTER", msg.sender), "JackPotTicket:CANT_MINT");

    for (uint256 i = 0; i < amount; i++) {
      _mint(to, _tokenCounter);
      _tokenCounter++;
    }
  }

  function _validateCreateParam(
    bytes32 hashedServerSeedParam,
    address tokenAddr,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, tokenAddr, hashedServerSeedParam));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("CREATOR", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function createRound(
    bytes32 hashedServerSeedParam,
    address tokenAddr,
    Sig calldata sig
  ) public {
    require(block.timestamp >= openTime, "JackPotTicket:NOT_FINISHED");
    require(
      _validateCreateParam(hashedServerSeedParam, tokenAddr, sig),
      "JackPotTicket:NOT_CREATOR"
    );

    uint256 totalAmount = IERC20(tokenAddr).balanceOf(address(this));
    require(totalAmount > 0, "JackPotTicket:INSUFFICIENT_BALANCE");

    hashedServerSeed = hashedServerSeedParam;
    _serverSeed = bytes32(0);

    openTime = block.timestamp + period;
    totalDistributeAmount = totalAmount;
    token = tokenAddr;
    clientSeed = bytes32(0);
    for (uint256 i = 0; i < _tokenCounter; i++) {
      rewarded[ownerOf(i)] = false;
    }
    IERC20(token).transfer(_treasuryAddr, totalAmount / 20);
  }

  function _validateFinishParam(bytes32 serverSeedParam, Sig calldata sig)
    private
    view
    returns (bool)
  {
    bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, serverSeedParam));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("CREATOR", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function finishRound(bytes32 serverSeed, Sig calldata sig) public {
    require(_validateFinishParam(serverSeed, sig), "JackPotTicket:NOT_CREATOR");
    require(
      keccak256(abi.encodePacked(serverSeed, token)) == hashedServerSeed,
      "JackPotTicket:INVALID_SEED"
    );
    require(block.timestamp > openTime, "JackPotTicket:NOT_FINISHED");
    _serverSeed = serverSeed;
  }

  function getResult() public view hasTicket returns (uint256) {
    require(block.timestamp > openTime, "JackPotTicket:NOT_FINISHED");
    require(_serverSeed != bytes32(0), "JackPotTicket:NO_SERVERSEED");

    uint256 total = _tokenCounter;
    address[] memory addressList = getAddressList();
    uint256 reward = 0;

    bytes32 hashed = keccak256(abi.encodePacked(_serverSeed, clientSeed, total));
    uint256 winnerIndex = uint256(hashed) % total;

    if (msg.sender == addressList[winnerIndex]) {
      reward += (totalDistributeAmount * 80) / 100; // 80% to winner
    }

    for (uint256 i = 1; i < 11; i++) {
      if (msg.sender == addressList[(winnerIndex + i) % total]) {
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

    IERC20(token).transfer(msg.sender, reward);
  }

  // for provably
  function getServerSeed() public view returns (bytes32) {
    require(block.timestamp > openTime, "JackPotTicket:NOT_FINISHED");
    // require(_serverSeed != bytes32(0), "JackPotTicket:NOT_FINISHED");
    return _serverSeed;
  }

  function getHashedServerSeed() public view returns (bytes32) {
    return hashedServerSeed;
  }

  function getOpenTime() public view returns (uint256) {
    return openTime;
  }

  function getAddressList() public view returns (address[] memory) {
    address[] memory addressList = new address[](_tokenCounter);
    for (uint256 i = 0; i < _tokenCounter; i++) {
      addressList[i] = ownerOf(i);
    }

    return addressList;
  }

  function getTotalReward() public view returns (string memory tokenName, uint256 amount) {
    tokenName = IERC20Metadata(token).symbol();
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

  function setSeedString(string memory seedStr) public hasTicket {
    clientSeed = keccak256(abi.encodePacked(clientSeed, msg.sender, seedStr));
  }

  function getClientSeed() public view hasTicket returns (bytes32) {
    return clientSeed;
  }
}
