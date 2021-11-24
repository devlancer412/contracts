// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract RoosterEgg is ERC1155, Ownable, Pausable {
  // Presale time in UNIX
  uint128 public openingTime;
  uint128 public closingTime;

  //USDC address
  IERC20 public immutable usdc;

  // Value wallet address
  address public immutable wallet;

  //Max supply for round
  uint32 public supply;

  //Tokens sold for round
  uint32 public sold;

  //Indivisual cap for round (0 to disable)
  uint32 public cap;

  //Sale round
  uint8 public round;

  //Number of egg type
  uint8 public types;

  //The price per NFT token (1token = ? wei)
  uint256 public price;

  //round => user => amount
  mapping(uint8 => mapping(address => uint32)) public purchasedAmount;

  event Purchase(address indexed purchaser, uint8 indexed round, uint256 amount, uint256 cost);
  event NewPresale(uint8 round, uint32 cap, uint128 openingTime, uint128 closingTime, uint256 price, bool isPublicSale);

  constructor(
    IERC20 usdc_,
    address wallet_,
    string memory uri_
  ) ERC1155(uri_) {
    usdc = usdc_;
    wallet = wallet_;
  }

  function isOpen() public view returns (bool) {
    return block.timestamp >= openingTime && block.timestamp <= closingTime;
  }

  function getTime() external view returns (uint32) {
    return uint32(block.timestamp);
  }

  function buyEggs(uint32 amount) external {
    address purchaser = _msgSender();
    uint256 value = price * amount;

    //Checks
    _preValidatePurchase(purchaser, amount);

    //Effects
    sold += amount; //amount is no more than 10
    purchasedAmount[round][purchaser] += uint32(amount);

    //Interactions
    usdc.transferFrom(purchaser, wallet, value);
    _mintRandom(purchaser, amount);

    emit Purchase(purchaser, round, amount, value);
  }

  function _preValidatePurchase(
    address purchaser,
    uint32 amount
  ) private view whenNotPaused {
    require(isOpen(), "Not open");
    require(amount > 0 && amount <= 10, "Must be > 0 and <= 10");
    require(sold + uint32(amount) <= supply, "Exceeds supply");
    if(cap > 0){
      require(amount + purchasedAmount[round][purchaser] <= cap, "Exceeds cap");
    }
  }

  function _mintRandom(
    address purchaser,
    uint32 amount
  ) private {
    uint256 id = 
      uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, purchaser, amount))) % types;
    for(uint32 i = 0; i < amount; i++){
      id = id < types ? id : 0;
      _mint(purchaser, id++, 1, "");
    }
  }

  /* Only owner functions */

  function setURI(string memory uri_) public onlyOwner {
    _setURI(uri_);
  }

  function mint(
    address account,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) external onlyOwner {
    _mint(account, id, amount, data);
  }

  function mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) external onlyOwner {
    _mintBatch(to, ids, amounts, data);
  }
}
