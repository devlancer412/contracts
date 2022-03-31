// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
  Marketplace spec: https://www.notion.so/RoosterWars-Marketplace-6350187ee37f4e239aa8441b7e634e00
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./Claimable.sol";

contract Store is Ownable, Claimable {
  IERC20 public operatingToken;
  uint256 public feeRate;
  address immutable vault;

  enum TokenType {
    ERC1155,
    ERC1155EXT,
    ERC721,
    ERC721EXT
  }

  struct Listing {
    address token;
    uint256 tokenId;
    address owner;
    uint256 price;
    TokenType tokentype;
    uint256 maxval;
  }

  uint256 public nextId;
  // { listingId: Listing}
  mapping(uint256 => Listing) public listings;
  mapping(uint256 => bool) public inactive;
  // { listingId: inStock }
  mapping(uint256 => uint256) public stocks;
  // { account: allowed }
  mapping(address => bool) public allowedLister;
  // { account: block.number}
  mapping(address => uint256) public last_purchase;

  event Listed(
    uint256 listingId,
    address token,
    uint256 tokenId,
    address owner,
    uint256 amount,
    uint256 price,
    TokenType tokentype
  );
  event Sold(uint256 listingId, address indexed buyer, uint256 amount);
  event Revoke(uint256 listingId);

  constructor(IERC20 _operatingToken, address _vault) {
    operatingToken = _operatingToken;
    vault = _vault;
  }

  /*
        setAllowedLister gives an account access to call the makeListing method.
    */
  function setAllowedLister(address account, bool allowed) public onlyOwner {
    allowedLister[account] = allowed;
  }

  /*
        setFeeRate sets the fee in down to a hundredth of a percent.
        1    =    0.01%
        100  =   10.00%
        1000 =  100.00%
    */
  function setFeeRate(uint256 _feeRate) public onlyOwner {
    feeRate = _feeRate;
  }

  /*
        restock refills the amount of tokens the contract is allowed to muint
    */
  function restock(uint256 listingId, uint256 amount) public {
    require(listings[listingId].owner == msg.sender, "not listing owner");
    stocks[listingId] += amount;
  }

  /*
        makeListing creates a listing based on the tokenType
            Token types with an EX suffix is expected to have a mint() function with an additional
        argument where the shop passes a random number based on the 'maxval' argument.
            The random value is [0, maxval). And is generated through the signer's signature.
    */
  function makeListing(
    TokenType tokenType,
    address token,
    uint256 tokenId,
    uint256 amount,
    uint256 price,
    uint256 maxval
  ) public returns (uint256) {
    require(allowedLister[msg.sender], "STORE:NOT_AUTHORIZED");
    unchecked {
      nextId = nextId + 1;
    }

    // Verify that it conforms to the Mintable interface by making sure the mint method can be called.
    bytes memory payload = _generatePayload(msg.sender, tokenType, tokenId, 1, 0, "", 0);
    (bool ok, ) = token.call(payload);
    console.log("Calling:", uint256(tokenType));
    require(ok, "Store:TOKEN_VALIDATE_FAILED");

    if (feeRate != 0) {
      price += (price * feeRate) / 10_000;
    }

    listings[nextId] = Listing(token, tokenId, msg.sender, price, tokenType, maxval);
    stocks[nextId] = amount;

    emit Listed(nextId, token, tokenId, msg.sender, amount, price, tokenType);
    return nextId;
  }

  /*
        reprice changes the listing's price.
    */
  function reprice(uint256 listingId, uint256 price) public {
    require(listings[listingId].owner == msg.sender, "only owner can reprice the listing");

    if (feeRate != 0) {
      price += (price * feeRate) / 10_000;
    }

    Listing memory l = listings[listingId];
    l.price = price;
    listings[listingId] = l;
  }

  /*
        setActive changes the listing's state.
    */
  function setActive(uint256 listingId, bool active) public {
    require(listings[listingId].owner == msg.sender, "only listing owner can revoke the listing");

    inactive[listingId] = active;
    emit Revoke(listingId);
  }

  function _generatePayload(
    address recv,
    TokenType tokentype,
    uint256 id,
    uint256 amount,
    uint256 i,
    bytes32 r,
    uint256 max
  ) internal view returns (bytes memory payload) {
    if (tokentype == TokenType.ERC1155) {
      console.log("Mining as ERC1155");
      payload = abi.encodeWithSignature("mint(address,uint256,uint256)", recv, id, amount);
    } else if (tokentype == TokenType.ERC1155EXT) {
      uint256 unique = uint256(keccak256(abi.encodePacked(r, i)));

      if (max > 0) {
        unique = unique % max;
      }
      payload = abi.encodeWithSignature(
        "mint(address,uint256,uint256,uint256)",
        recv,
        id,
        amount,
        unique
      );
    } else if (tokentype == TokenType.ERC721) {
      payload = abi.encodeWithSignature("mint(address)", recv);
    } else if (tokentype == TokenType.ERC721EXT) {
      uint256 unique = uint256(keccak256(abi.encodePacked(r, i)));

      if (max > 0) {
        unique = unique % max;
      }
      payload = abi.encodeWithSignature("mint(address,uint256)", recv, unique);
    }
  }

  function purchase(
    address to,
    uint256[] calldata listingIds,
    uint256[] calldata amounts,
    Claim calldata claimData
  ) public {
    require(claimData.target == msg.sender, "Store:NOT_AUTHORIZED");
    require(validateClaim(claimData), "Store:INVALID_CLAIM");
    require(claimData.amount == last_purchase[msg.sender], "Store:OLD_CLAIM");
    _burn_nonce(claimData.nonce);
    last_purchase[msg.sender] = block.number;

    require(listingIds.length == amounts.length, "Store:PARAMETER_MISMATCH");

    for (uint256 i = 0; i < listingIds.length; i++) {
      uint256 amount = amounts[i];
      uint256 listingId = listingIds[i];

      require(!inactive[listingId], "Store:INACTIVE_LISTING");
      require(stocks[listingId] >= amount, "Store:INSUFFICIENT_STOCK");

      Listing memory listing = listings[listingId];

      stocks[listingId] -= amount;
      uint256 price = listing.price * amount;
      if (feeRate != 0) {
        uint256 fee = (price * feeRate) / 10_000;
        price -= fee;
        // Send the fee to the contract owner
        operatingToken.transferFrom(msg.sender, vault, fee);
      }
      operatingToken.transferFrom(msg.sender, listing.owner, price);

      bytes memory payload = _generatePayload(
        to,
        listing.tokentype,
        listing.tokenId,
        amount,
        i,
        claimData.signature.r,
        listing.maxval
      );

      (bool ok, ) = listing.token.call(payload);
      require(ok);

      emit Sold(listingId, claimData.target, amount);
    }
  }

  // function purchaseBulk(uint256[] calldata listingIds, uint256[] calldata amounts) public {
  //     require(listingIds.length == amounts.length, "array count mismatch");
  //     for (uint256 i = 0; i < listingIds.length; i++) {
  //         _purchase(listingIds[i], amounts[i]);
  //     }
  // }
}
