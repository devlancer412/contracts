// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";

interface Egg {
  function mintEggs(address to, uint256 amount) external;

  function purchasedAmount(address user) external view returns (uint8);
}

//solhint-disable avoid-low-level-calls
contract RoosterEggSale is Pausable, Ownable {
  //Presale struct
  Presale public presale;

  //RoosterEgg address
  Egg public immutable egg;

  //USDC address
  IERC20 public immutable usdc;

  //Vault address
  address public immutable vault;

  //Signer address
  address public immutable signer;

  //Total minted
  uint256 public minted;

  //Max supply
  uint256 public constant maxSupply = 150_000;

  //user => amount
  mapping(address => uint256) public purchasedAmount;
  //Egg minter
  mapping(address => bool) public minter;
  //Nonce used
  mapping(bytes32 => bool) private _nonceUsed;

  event Purchase(address indexed purchaser, uint256 amount, uint256 value);
  event NewPresale(
    uint256 supply,
    uint256 cap,
    uint256 openingTime,
    uint256 closingTime,
    bool whitelist,
    uint256 price,
    uint256 cashback
  );
  event MaticCashback(address user, uint256 amount);
  event MaticCashbackFailed(address indexed user, uint256 balance);

  struct Presale {
    uint32 supply;
    uint32 cap;
    uint32 sold;
    uint32 openingTime;
    uint32 closingTime;
    bool whitelist;
    uint256 price;
    uint256 cashback;
  }

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  constructor(
    IERC20 usdc_,
    Egg egg_,
    address vault_,
    address signer_,
    uint256 minted_
  ) {
    usdc = usdc_;
    egg = egg_;
    vault = vault_;
    signer = signer_;
    minted = minted_;
  }

  receive() external payable {}

  function isOpen() public view returns (bool) {
    return block.timestamp >= presale.openingTime && block.timestamp <= presale.closingTime;
  }

  function getTime() external view returns (uint32) {
    return uint32(block.timestamp);
  }

  function buyEggs(
    uint8 amount,
    bytes32 nonce,
    Sig calldata sig
  ) external whenNotPaused {
    address purchaser = msg.sender;
    uint256 value = presale.price * amount;
    uint256 cashbackAmount = presale.cashback * amount;

    //Checks
    require(isOpen(), "Not open");
    require(minted + amount <= maxSupply, "Exceeds max supply");
    require(presale.sold + amount <= presale.supply, "Exceeds supply");
    require(
      purchasedAmount[purchaser] + egg.purchasedAmount(purchaser) + amount <= presale.cap,
      "Exceeds cap"
    );
    if (presale.whitelist) {
      require(_nonceUsed[nonce], "Nonce used");
      require(_isWhitelisted(purchaser, nonce, sig), "Not whitelisted");
      _nonceUsed[nonce] = true;
    }

    //Effects
    minted += amount;
    presale.sold += amount;
    purchasedAmount[purchaser] += amount;

    //Interactions
    usdc.transferFrom(purchaser, vault, value);

    if (cashbackAmount > 0) {
      (bool success, ) = payable(purchaser).call{value: cashbackAmount}("");
      if (success) {
        emit MaticCashback(purchaser, cashbackAmount);
      } else {
        emit MaticCashbackFailed(purchaser, address(this).balance);
      }
    }

    emit Purchase(purchaser, amount, value);
  }

  function _isWhitelisted(
    address user,
    bytes32 nonce,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(user, nonce));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s) == signer;
  }

  /* Only owner functions */

  function setPresale(
    uint32 openingTime,
    uint32 closingTime,
    uint32 supply,
    uint32 cap,
    bool whitelist,
    uint256 price,
    uint256 cashback
  ) external onlyOwner {
    if (!isOpen()) {
      require(closingTime >= openingTime, "Closing time < Opening time");
      require(openingTime > block.timestamp, "Invalid opening time");
      presale.openingTime = openingTime;
    }

    presale.closingTime = closingTime;
    presale.supply = supply;
    presale.cap = cap;
    presale.whitelist = whitelist;
    presale.price = price;
    presale.cashback = cashback;

    emit NewPresale(supply, cap, openingTime, closingTime, whitelist, price, cashback);
  }

  function mintEggs(address to, uint256 amount) external {
    require(minter[msg.sender], "Only minter");
    require(minted + amount <= presale.supply, "Exceeds supply");
    minted += amount;
    egg.mintEggs(to, amount);
  }

  function withdrawMatic(uint256 amount) external {
    address user = msg.sender;
    require(user == owner() || user == vault, "Invalid access");
    (bool success, ) = payable(vault).call{value: amount}("");
    require(success, "Withdraw failed");
  }

  function grantMinterRole(address user) external onlyOwner {
    minter[user] = true;
  }

  function revokeMinterRole(address user) external onlyOwner {
    minter[user] = false;
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }
}
