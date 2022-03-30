// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AccessControl.sol";

// import "hardhat/console.sol";

interface Egg {
  function mintEggs(address to, uint256 amount) external;

  function setBaseURI(string memory baseURI_) external;

  function transferOwnership(address newOwner) external;

  function purchasedAmount(address user) external view returns (uint8);
}

//solhint-disable avoid-low-level-calls
contract RoosterEggSale is AccessControl {
  //EggSale struct
  EggSale public eggsale;

  //RoosterEgg address
  Egg public immutable egg;

  //USDC address
  IERC20 public immutable usdc;

  //Vault address
  address public immutable vault;

  //Whitelist verification signer address
  address public immutable signer;

  //Total minted
  uint256 public minted;

  //Max supply of eggs
  uint256 public constant maxSupply = 150_000;

  //User egg purchased amount (user => amount)
  mapping(address => uint256) public purchasedAmount;
  //Check if nonce is used (nonce => boolean)
  mapping(bytes32 => bool) private _nonceUsed;

  event Purchase(address indexed purchaser, uint256 amount, uint256 value);
  event EggSaleSet(
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

  struct EggSale {
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
    address usdc_,
    address egg_,
    address vault_,
    address signer_,
    uint256 minted_
  ) {
    usdc = IERC20(usdc_);
    egg = Egg(egg_);
    vault = vault_;
    signer = signer_;
    minted = minted_;
  }

  receive() external payable {}

  function isOpen() public view returns (bool) {
    return block.timestamp >= eggsale.openingTime && block.timestamp < eggsale.closingTime;
  }

  function buyEggs(
    uint8 amount,
    bytes32 nonce,
    Sig calldata sig
  ) external whenNotPaused {
    address purchaser = msg.sender;
    uint256 value = eggsale.price * amount;
    uint256 cashbackAmount = eggsale.cashback * amount;

    //Basic chekcs
    require(isOpen(), "Not open");
    require(minted + amount <= maxSupply, "Exceeds max supply");
    require(eggsale.sold + amount <= eggsale.supply, "Exceeds supply");
    require(
      purchasedAmount[purchaser] + egg.purchasedAmount(purchaser) + amount <= eggsale.cap,
      "Exceeds cap"
    );

    //Whitelist check
    if (eggsale.whitelist) {
      require(!_nonceUsed[nonce], "Nonce used");
      require(_isWhitelisted(purchaser, nonce, sig), "Not whitelisted");
      _nonceUsed[nonce] = true;
    }

    //Effects
    unchecked {
      minted += amount;
      eggsale.sold += amount;
      purchasedAmount[purchaser] += amount;
    }

    //Interactions
    usdc.transferFrom(purchaser, vault, value);

    egg.mintEggs(purchaser, amount);

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

  function setEggSale(
    uint32 openingTime,
    uint32 closingTime,
    uint32 supply,
    uint32 cap,
    bool whitelist,
    uint256 price,
    uint256 cashback
  ) external onlyOwner {
    require(closingTime >= openingTime, "Closing time < Opening time");

    if (!isOpen()) {
      require(openingTime > block.timestamp, "Invalid opening time");
      eggsale.openingTime = openingTime;
      eggsale.sold = 0;
    }

    eggsale.closingTime = closingTime;
    eggsale.supply = supply;
    eggsale.cap = cap;
    eggsale.whitelist = whitelist;
    eggsale.price = price;
    eggsale.cashback = cashback;

    emit EggSaleSet(supply, cap, openingTime, closingTime, whitelist, price, cashback);
  }

  function mintEggs(address to, uint256 amount) external onlyMinter {
    require(minted + amount <= maxSupply, "Exceeds max supply");
    unchecked {
      minted += amount;
    }
    egg.mintEggs(to, amount);
  }

  function setBaseURI(string memory baseURI_) external onlyOwner {
    egg.setBaseURI(baseURI_);
  }

  function withdrawMatic(uint256 amount) external onlyOwner {
    (bool success, ) = payable(vault).call{value: amount}("");
    require(success, "Withdraw failed");
  }

  function transferEggContractOwnership(address newOwner) external onlyOwner {
    egg.transferOwnership(newOwner);
  }
}
