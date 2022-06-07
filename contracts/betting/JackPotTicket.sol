// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";
import {IJackPotTicket} from "./IJackPotTicket.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "hardhat/console.sol";

contract JackPotTicket is Auth {
  // Token name
  string private _name;

  // Token symbol
  string private _symbol;

  // Mapping from token ID to owner address
  mapping(uint256 => address) private _owners;

  // Mapping owner address to token count
  mapping(address => uint256) private _balances;

  uint256 private _tokenCounter;
  bytes32 private _serverSeed;
  address private _treasuryAddr;
  string private _baseTokenURI;

  uint256 public closeTime;
  uint256 public openTime;
  uint256 public period;
  uint256 public withdrawPeriod;
  uint256 public totalDistributeAmount;
  bytes32 public hashedServerSeed;
  bytes32 public clientSeed;
  address public token;
  mapping(address => bool) public allowedTokens;

  mapping(uint256 => mapping(address => bool)) private rewarded;
  uint256 public currentRound;

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  constructor() {
    _name = "RoosterWarsJackpotTicket";
    _symbol = "RWJT";
    period = 1 weeks;
    withdrawPeriod = 3 days;
    _treasuryAddr = msg.sender;
    closeTime = block.timestamp;
    openTime = block.timestamp;
  }

  /**
   * @dev See {JackPotTicket-balanceOf}.
   */
  function balanceOf(address owner) public view virtual returns (uint256) {
    require(owner != address(0), "JackPotTicket: balance query for the zero address");
    return _balances[owner];
  }

  /**
   * @dev See {JackPotTicket-ownerOf}.
   */
  function ownerOf(uint256 tokenId) public view virtual returns (address) {
    address owner = _owners[tokenId];
    require(owner != address(0), "JackPotTicket: owner query for nonexistent token");
    return owner;
  }

  /**
   * @dev See {JackPotTicket-name}.
   */
  function name() public view virtual returns (string memory) {
    return _name;
  }

  /**
   * @dev See {JackPotTicket-symbol}.
   */
  function symbol() public view virtual returns (string memory) {
    return _symbol;
  }

  /**
   * @dev Mints `tokenId` and transfers it to `to`.
   *
   * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
   *
   * Requirements:
   *
   * - `tokenId` must not exist.
   * - `to` cannot be the zero address.
   *
   * Emits a {Transfer} event.
   */
  function _mint(address to, uint256 tokenId) internal virtual {
    require(to != address(0), "JackPotTicket: mint to the zero address");
    require(!_exists(tokenId), "JackPotTicket: token already minted");

    _balances[to] += 1;
    _owners[tokenId] = to;
  }

  /**
   * @dev Returns whether `tokenId` exists.
   *
   * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
   *
   * Tokens start existing when they are minted (`_mint`),
   * and stop existing when they are burned (`_burn`).
   */
  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return _owners[tokenId] != address(0);
  }

  modifier hasTicket() {
    require(balanceOf(msg.sender) > 0, "JackPotTicket:NO_TICKET");
    _;
  }

  function mintTo(uint256 amount, address to) public {
    require(hasRole("MINTER", msg.sender), "JackPotTicket:CANT_MINT");

    uint256 tokenId = _tokenCounter;
    for (uint256 i = 0; i < amount; i++) {
      _mint(to, tokenId);
      tokenId++;
    }

    _tokenCounter = tokenId;
  }

  function _validateCreateParam(
    bytes32 hashedServerSeedParam,
    address tokenAddr,
    Sig calldata sig
  ) private view onlyRole("MAINTAINER") returns (bool) {
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
    require(allowedTokens[tokenAddr], "JackPotTicket:INVALID_TOKEN");
    require(block.timestamp >= openTime, "JackPotTicket:NOT_REWARDED");
    require(
      _validateCreateParam(hashedServerSeedParam, tokenAddr, sig),
      "JackPotTicket:NOT_CREATOR"
    );

    uint256 totalAmount = IERC20(tokenAddr).balanceOf(address(this));
    require(totalAmount > 0, "JackPotTicket:INSUFFICIENT_BALANCE");

    hashedServerSeed = hashedServerSeedParam;
    _serverSeed = bytes32(0);

    closeTime = block.timestamp + period;
    totalDistributeAmount = totalAmount;
    token = tokenAddr;
    clientSeed = bytes32(0);
    currentRound++;
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

  function finishRound(bytes32 serverSeed, Sig calldata sig) public onlyRole("MAINTAINER") {
    require(_validateFinishParam(serverSeed, sig), "JackPotTicket:NOT_CREATOR");
    require(
      keccak256(abi.encodePacked(serverSeed, token)) == hashedServerSeed,
      "JackPotTicket:INVALID_SEED"
    );
    require(block.timestamp > closeTime, "JackPotTicket:NOT_FINISHED");
    openTime = block.timestamp + withdrawPeriod;
    _serverSeed = serverSeed;
  }

  function getResult() public view hasTicket returns (uint256) {
    require(block.timestamp > closeTime, "JackPotTicket:NOT_FINISHED");
    require(_serverSeed != bytes32(0), "JackPotTicket:NO_SERVERSEED");
    require(block.timestamp < openTime, "JackPotTicket:TIME_OVER");

    address[] memory addressList = getWinnerAddressList();
    uint256 reward = 0;

    if (msg.sender == addressList[0]) {
      reward += (totalDistributeAmount * 80) / 100; // 80% to winner
    }

    for (uint256 i = 1; i < 11; i++) {
      if (msg.sender == addressList[i]) {
        reward += (totalDistributeAmount * 15) / 1000; // 1.5% to winners
      }
    }

    return reward;
  }

  function withdrawReward() public {
    uint256 reward = getResult();
    require(reward > 0, "JackPotTicket:NO_REWARD");
    require(rewarded[currentRound - 1][msg.sender] == false, "JackPotTicket:REWARDED");

    rewarded[currentRound - 1][msg.sender] = true;

    IERC20(token).transfer(msg.sender, reward);
  }

  // for provably
  function getServerSeed() public view returns (bytes32) {
    require(block.timestamp > closeTime, "JackPotTicket:NOT_FINISHED");
    // require(_serverSeed != bytes32(0), "JackPotTicket:NOT_FINISHED");
    return _serverSeed;
  }

  function getHashedServerSeed() public view returns (bytes32) {
    return hashedServerSeed;
  }

  function getCloseTime() public view returns (uint256) {
    return closeTime;
  }

  function getWinnerAddressList() public view returns (address[] memory) {
    address[] memory addressList = new address[](11);
    uint256 total = _tokenCounter;

    bytes32 hashed = keccak256(abi.encodePacked(_serverSeed, clientSeed, total));

    for (uint256 i = 0; i < 11; i++) {
      hashed = keccak256(abi.encodePacked(hashed, _serverSeed, clientSeed, total));
      uint256 winnerIndex = uint256(hashed) % total;
      addressList[i] = ownerOf(winnerIndex % total);
    }

    return addressList;
  }

  function getAddressList() public view returns (address[] memory) {
    uint256 total = _tokenCounter;
    address[] memory addressList = new address[](total);

    for (uint256 i = 0; i < total; i++) {
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
  function tokenURI(uint256 _tokenId) public view returns (string memory) {
    return _baseTokenURI;
  }

  function setSeedString(bytes32 seedStr) public hasTicket {
    clientSeed = keccak256(abi.encodePacked(clientSeed, msg.sender, seedStr));
  }

  function setTokenAllowance(address _token, bool value) public onlyOwner {
    allowedTokens[_token] = value;
  }
}
