// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

// import "hardhat/console.sol";

contract RoosterEgg is ERC721, ERC721Burnable, Ownable, Pausable {
  using Strings for uint256;

  // Presale time in UNIX
  uint32 public openingTime;
  uint32 public closingTime;

  //Max supply for round
  uint24 public supply;

  //Tokens sold for round
  uint24 public sold;

  //Indivisual cap for round
  uint24 public cap;

  //Current tokenID count
  uint24 private _tokenIdCounter;

  //The price per egg (1egg = ? wei)
  uint256 public price;

  //Matic cashback per egg
  uint256 public cashbackPerEgg;

  //USDC address
  IERC20 public immutable usdc;

  // Vault wallet address
  address public immutable wallet;

  //Base URI
  string public baseURI;

  //user => amount
  mapping(address => uint8) public purchasedAmount;

  event Purchase(address indexed purchaser, uint8 amount, uint256 value);
  event NewPresale(
    uint24 supply,
    uint24 cap,
    uint32 openingTime,
    uint32 closingTime,
    uint256 price,
    uint256 cashbackPerEgg
  );
  event MaticReceived(address user, uint256 amount);
  event MaticWithdrawn(uint256 amount);
  event MaticCashback(address user, uint256 amount);
  event MaticCashbackFailed(address indexed user, uint256 balance);

  constructor(
    IERC20 usdc_,
    address wallet_,
    uint24 inititalTokenId_,
    string memory baseURI_
  ) ERC721("RoosterEgg", "ROOSTER_EGG") {
    usdc = usdc_;
    wallet = wallet_;
    baseURI = baseURI_;
    _tokenIdCounter = inititalTokenId_;
  }

  receive() external payable {
    emit MaticReceived(msg.sender, msg.value);
  }

  function isOpen() public view returns (bool) {
    return block.timestamp >= openingTime && block.timestamp <= closingTime;
  }

  function getTime() external view returns (uint32) {
    return uint32(block.timestamp);
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(bytes(baseURI).length > 0, "BaseURI not set");
    require(_exists(tokenId), "Query for nonexistent token");
    return string(abi.encodePacked(baseURI, tokenId.toString()));
  }

  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  function buyEggs(uint8 amount) external {
    address purchaser = _msgSender();
    uint256 value = price * amount;
    uint256 cashbackAmount = cashbackPerEgg * amount;

    //Checks
    _preValidatePurchase(purchaser, amount);

    //Effects
    sold += amount;
    purchasedAmount[purchaser] += amount;

    //Interactions
    usdc.transferFrom(purchaser, wallet, value);
    _mintEggs(purchaser, amount);

    (bool success, ) = payable(purchaser).call{value: cashbackAmount}("");
    if (success) {
      emit MaticCashback(purchaser, cashbackAmount);
    } else {
      emit MaticCashbackFailed(purchaser, address(this).balance);
    }

    emit Purchase(purchaser, amount, value);
  }

  function burnBatch(uint24[] calldata tokenIds) external {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      burn(tokenIds[i]);
    }
  }

  function _preValidatePurchase(address purchaser, uint8 amount) private view whenNotPaused {
    require(isOpen(), "Not open");
    require(sold + amount <= supply, "Exceeds supply");
    require(amount + purchasedAmount[purchaser] <= cap, "Exceeds cap");
  }

  function _mintEggs(address to, uint256 amount) private {
    uint24 newtokenId = _tokenIdCounter;

    for (uint256 i = 0; i < amount; i++) {
      _safeMint(to, newtokenId++);
    }

    _tokenIdCounter = newtokenId;
  }

  /* Only owner functions */

  function setPresale(
    uint32 openingTime_,
    uint32 closingTime_,
    uint24 supply_,
    uint24 cap_,
    uint256 price_,
    uint256 cashbackPerEgg_
  ) external onlyOwner {
    require(!isOpen() || paused(), "Cannot set now");
    if (!isOpen()) {
      require(closingTime_ >= openingTime_, "Closing time < Opening time");
      require(openingTime_ > block.timestamp, "Invalid opening time");
      openingTime = openingTime_;
    }

    supply = supply_;
    cap = cap_;
    price = price_;
    closingTime = closingTime_;
    cashbackPerEgg = cashbackPerEgg_;

    emit NewPresale(supply_, cap_, openingTime_, closingTime_, price_, cashbackPerEgg_);
  }

  function mintEggs(address to, uint256 amount) external onlyOwner {
    _mintEggs(to, amount);
  }

  function setBaseURI(string memory baseURI_) external onlyOwner {
    baseURI = baseURI_;
  }

  function withdrawMatic(uint256 amount) external {
    address user = msg.sender;
    require(user == owner() || user == wallet, "Invalid access");
    (bool success, ) = payable(wallet).call{value: amount}("");
    require(success, "Withdraw failed");
    emit MaticWithdrawn(amount);
  }
}
