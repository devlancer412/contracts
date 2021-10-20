// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "hardhat/console.sol";

interface IToken {
  function safeMint(address, uint256) external;
}

contract Presale is Ownable, Pausable {
  // Presale time in UNIX
  uint128 public openingTime;
  uint128 public closingTime;

  //The price per NFT token (1token = ? wei)
  uint256 public price;

  //The NFT token for safe
  IToken public immutable token;

  //WETH (Wrapped Ether)
  IERC20 public immutable weth;

  // Withdraw address (should be a multisig)
  address public wallet;

  //Signer of signatures
  address public signer;

  //Max supply for round
  uint32 public cap;

  //Tokens sold for round
  uint32 public sold;

  //Sale round
  uint8 public round;

  //Private or public sale
  bool public isPublicSale;

  event Purchase(address indexed purchaser, uint8 indexed round, uint256 amount, uint256 cost);
  event NewPresale(uint8 round, uint32 cap, uint128 openingTime, uint128 closingTime, uint256 price, bool isPublicSale);

  constructor(
    IToken token_,
    IERC20 weth_,
    address wallet_,
    address signer_
  ) {
    token = token_;
    weth = weth_;
    wallet = wallet_;
    signer = signer_;
  }

  function isOpen() public view returns (bool) {
    return block.timestamp >= openingTime && block.timestamp <= closingTime;
  }

  function getTime() external view returns (uint256) {
    return block.timestamp;
  }

  function buyNFT(uint256 amount, bytes memory whitelistSig) external {
    address purchaser = _msgSender();
    uint256 value = price * amount;

    //Checks
    _preValidatePurchase(purchaser, amount, whitelistSig);

    //Effects
    sold += uint32(amount); //amount is no more than 10

    //Interactions
    weth.transferFrom(purchaser, address(this), value);
    token.safeMint(purchaser, amount);

    emit Purchase(purchaser, round ,amount, value);
  }

  function _preValidatePurchase(
    address purchaser,
    uint256 amount,
    bytes memory whitelistSig
  ) private view whenNotPaused {
    require(isOpen(), "Not open");
    if (!isPublicSale) {
      bool whitelisted = _verify(purchaser, whitelistSig);
      require(whitelisted, "Invalid access");
    }
    require(amount > 0 && amount <= 10, "Must be > 0 and <= 10");
    require(sold + uint32(amount) <= cap, "Exceeds cap");
  }

  /* Whitelist verification */

  function _verify(address user, bytes memory signature) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(user, address(this), round));
    bytes32 ethSignedMessageHash = _getEthSignedMessageHash(messageHash);
    return _recoverSigner(ethSignedMessageHash, signature) == signer;
  }

  function _getEthSignedMessageHash(bytes32 messageHash) private pure returns (bytes32) {
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
  }

  function _recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) private pure returns (address) {
    (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
    return ecrecover(ethSignedMessageHash, v, r, s);
  }

  function _splitSignature(bytes memory sig)
    private
    pure
    returns (
      bytes32 r,
      bytes32 s,
      uint8 v
    )
  {
    require(sig.length == 65, "Invalid signature length");
    assembly {
      r := mload(add(sig, 32))
      s := mload(add(sig, 64))
      v := byte(0, mload(add(sig, 96)))
    }
  }

  /* Only owner functions */

  function setPresale(
    uint128 openingTime_,
    uint128 closingTime_,
    uint256 price_,
    uint32 cap_,
    uint8 round_,
    bool isPublicSale_
  ) external onlyOwner {
    require(!isOpen() || paused(), "Cannot set now");
    if (!isOpen()) {
      require(closingTime_ >= openingTime_, "Closing time < Opening time");
      require(openingTime_ > block.timestamp, "Invalid opening time");
      openingTime = openingTime_;
      round = round_;
      sold = 0;
    }else{
      require(closingTime_ > block.timestamp, "Closing time < Opening time");
    }
    cap = cap_;
    price = price_;
    isPublicSale = isPublicSale_;
    closingTime = closingTime_;

    emit NewPresale(round, cap, openingTime, closingTime, price, isPublicSale);
  }

  function setSigner(address signer_) external onlyOwner {
    signer = signer_;
  }

  function updateWallet(address wallet_) external onlyOwner {
    wallet = wallet_;
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function withdrawFunds() external onlyOwner {
    uint256 amount = weth.balanceOf(address(this));
    weth.transfer(wallet, amount);
  }
}
