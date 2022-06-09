// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import "./IJackPotTicket.sol";
import "../utils/Auth.sol";
import "../utils/VRF/VRFv2Consumer.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "hardhat/console.sol";

contract JackPotTicket is Auth, VRFv2Consumer, IJackPotTicket {
  // Token name
  string private _name;

  // Token symbol
  string private _symbol;

  // Mapping from token ID to owner address
  mapping(uint256 => address) private _owners;

  // Mapping owner address to token count
  mapping(address => uint256) private _balances;

  uint256 private _tokenCounter;
  address private _treasuryAddr;
  string private _baseTokenURI;

  uint256 public closeTime;
  uint256 public openTime;
  uint256 public period;
  uint256 public withdrawPeriod;
  uint256 public totalDistributeAmount;
  bytes32 public clientSeed;
  address public token;
  mapping(address => bool) public allowedTokens;

  mapping(uint256 => mapping(address => bool)) private rewarded;
  mapping(uint256 => uint256) private requestIds;
  uint256 public currentRound;

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  constructor(uint64 subscriptionId, address vrfCoordinator)
    VRFv2Consumer(subscriptionId, vrfCoordinator)
  {
    _name = "RoosterWarsJackpotTicket";
    _symbol = "RWJT";
    period = 1 weeks;
    withdrawPeriod = 3 days;
    _treasuryAddr = msg.sender;
    closeTime = block.timestamp;
    openTime = block.timestamp;
    currentRound = 0;
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
   * @dev Returns true if this contract implements the interface defined by
   * `interfaceId`. See the corresponding
   * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
   * to learn more about how these ids are created.
   *
   * This function call must use less than 30 000 gas.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(IERC165)
    returns (bool)
  {
    return interfaceId == type(IJackPotTicket).interfaceId;
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

  function _validateCreateParam(address tokenAddr, Sig calldata sig)
    private
    view
    onlyRole("MAINTAINER")
    returns (bool)
  {
    bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, tokenAddr));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function createRound(address tokenAddr, Sig calldata sig) public {
    require(allowedTokens[tokenAddr], "JackPotTicket:INVALID_TOKEN");
    require(block.timestamp >= openTime, "JackPotTicket:NOT_REWARDED");
    require(_validateCreateParam(tokenAddr, sig), "JackPotTicket:NOT_SIGNER");

    uint256 totalAmount = IERC20(tokenAddr).balanceOf(address(this));
    require(totalAmount > 0, "JackPotTicket:INSUFFICIENT_BALANCE");

    closeTime = block.timestamp + period;
    totalDistributeAmount = totalAmount;
    token = tokenAddr;
    clientSeed = bytes32(0);
    IERC20(token).transfer(_treasuryAddr, totalAmount / 20);
  }

  function _validateFinishParam(Sig calldata sig) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(msg.sender));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function finishRound(Sig calldata sig) public onlyRole("MAINTAINER") returns (uint256) {
    require(_validateFinishParam(sig), "JackPotTicket:NOT_SIGNER");
    require(block.timestamp > closeTime, "JackPotTicket:NOT_FINISHED");
    openTime = block.timestamp + withdrawPeriod;
    currentRound++;
    requestIds[currentRound - 1] = requestRandomWords();

    emit NewRequest(requestIds[currentRound - 1]);

    return requestIds[currentRound - 1];
  }

  function getResult() public view hasTicket returns (uint256) {
    require(block.timestamp > closeTime, "JackPotTicket:NOT_FINISHED");
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

  function getCloseTime() public view returns (uint256) {
    return closeTime;
  }

  function getResultData() public view returns (uint256[] memory) {
    return s_randomWords[requestIds[currentRound - 1]];
  }

  function getRequestId() public view returns (uint256) {
    return requestIds[currentRound - 1];
  }

  function getWinnerAddressList() public view returns (address[] memory) {
    require(s_randomWords[requestIds[currentRound - 1]].length == 2, "JackPotTicket:NOT_FINISHED");
    address[] memory addressList = new address[](11);
    uint256 total = _tokenCounter;
    bytes32 serverSeed = keccak256(
      abi.encodePacked(
        s_randomWords[requestIds[currentRound - 1]][0],
        s_randomWords[requestIds[currentRound - 1]][1]
      )
    );

    bytes32 hashed = keccak256(abi.encodePacked(serverSeed, clientSeed, total));

    for (uint256 i = 0; i < 11; i++) {
      hashed = keccak256(abi.encodePacked(hashed, serverSeed, clientSeed, total));
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
  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    return _baseTokenURI;
  }

  function setSeedString(bytes32 seedStr) public hasTicket {
    clientSeed = keccak256(abi.encodePacked(clientSeed, msg.sender, seedStr));
  }

  function setTokenAllowance(address _token, bool value) public onlyOwner {
    allowedTokens[_token] = value;
  }

  function getServerSeed() public view returns (bytes32 serverSeed) {
    require(currentRound > 0, "JackPotTicket:NOT_YET");
    require(s_randomWords[requestIds[currentRound - 1]].length == 2, "JackPotTicket:NOT_FINISHED");
    return keccak256(abi.encodePacked(s_randomWords[0], s_randomWords[1]));
  }
}
