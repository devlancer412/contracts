pragma solidity ^0.8.0;

/**
  Marketplace spec: https://www.notion.so/RoosterWars-Marketplace-6350187ee37f4e239aa8441b7e634e00
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract Marketplace is Ownable {
  IERC20 public operatingToken;
  uint256 public feeRate;

  struct Listing {
    address token;
    uint256 tokenId;
    uint256 price;
    address owner;
    bool fungible;
    bool inactive;
  }

  uint256 public nextId;
  // { listingId: Listing}
  mapping(uint256 => Listing) public listings;
  // { listingId: inStock }
  mapping(uint256 => uint256) public stocks;
  // { contractAddress: allowed }
  mapping(address => bool) public allowedContracts;


  event Listed(
    uint256 listingId,
    address indexed token,
    uint256 indexed tokenId,
    address indexed owner,
    uint256 amount,
    uint256 price
  );
  event Live(uint256 listingId);
  event Sold(uint256 listingId, address indexed owner, uint256 amount);
  event Revoke(uint256 listingId);

  constructor(IERC20 _operatingToken, uint256 _fee) {
    operatingToken = _operatingToken;
    feeRate = _fee;
  }

  function setAllowedToken(address tokenAddress, bool allowed) public onlyOwner {
    allowedContracts[tokenAddress] = allowed;
  }

  function getListing(uint256 listingId)
    public
    view
    returns (
      address token,
      uint256 tokenId,
      uint256 price,
      address owner,
      bool fungible,
      bool inactive
    )
  {
    token = listings[listingId].token;
    tokenId = listings[listingId].tokenId;
    price = listings[listingId].price;
    owner = listings[listingId].owner;
    fungible = listings[listingId].fungible;
    inactive = listings[listingId].inactive;
  }

  function onERC721Received(
    address,
    address from,
    uint256 tokenId,
    bytes calldata
  ) public returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function onERC1155Received(
    address,
    address from,
    uint256 tokenId,
    uint256 amount,
    bytes calldata
  ) public returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  function makeListing(
    address token,
    uint256 tokenId,
    uint256 amount,
    uint256 price,
    bool fungible
  ) public returns (uint256) {
    nextId++;


    if (fungible) {
        IERC1155(token).transferFrom(msg.sender, address(this), tokenId, amount);      
        stocks[nextId] = amount;
    } else {
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);
    }

    listings[nextId] = Listing(token, tokenId, price, msg.sender, fungible, false);

    emit Listed(nextId, token, tokenId, msg.sender, amount, price);
    if (price > 0) {
      emit Live(nextId);
    }
    return nextId;
  }

  function setPrice(uint256 listingId, uint256 price) public {
    require(listings[listingId].owner == msg.sender, "only owner can set the listing as live");
    require(!listings[listingId].inactive, "cannnot reactivate revoked/sold listing");

    listings[listingId].price = price;
    if (price > 0) {
      emit Live(listingId);
    }
  }

  function isLive(uint256 listingId) public view returns (bool) {
    return listings[listingId].price != 0;
  }

  function revoke(uint256 listingId) public {
    require(listings[listingId].owner == msg.sender, "only listing owner can revoke the listing");
    require(!listings[listingId].inactive, "cannnot revoke revoked/sold listing");

    if (listings[listingId].fungible) {
      IERC1155 op = IERC1155(listings[listingId].token);
      op.safeTransferFrom(
        address(this),
        msg.sender,
        listings[listingId].tokenId,
        erc1155transfers[listings[listingId].token][listings[listingId].tokenId][msg.sender],
        ""
      );
      erc1155transfers[listings[listingId].token][listings[listingId].tokenId][msg.sender] = 0;
    } else {
      IERC721 op = IERC721(listings[listingId].token);
      op.safeTransferFrom(address(this), msg.sender, listings[listingId].tokenId);
      listings[listingId].inactive = true;
    }

    emit Revoke(listingId);
  }

  function _purchase1155(uint256 id, uint256 amount) private returns (uint256 price) {
    Listing memory listing = listings[id];
    require(stocks[id] != 0, "listing not in stock");
    require(stocks[id] >= amount, "not enough in stock");
    price = listing.price * amount;
    stocks[id] = stocks[id] - amount;

    IERC1155 op = IERC1155(listing.token);
    op.safeTransferFrom(address(this), msg.sender, listing.tokenId, amount, "");
  }

  function _purchase721(uint256 id) private returns (uint256 price) {
    Listing memory listing = listings[id];

    IERC721 op = IERC721(listing.token);
    op.safeTransferFrom(address(this), msg.sender, listing.tokenId);
    listing.inactive = true;
    return listing.price;
  }

  function purchase(uint256 listingId, uint256 amount) public {
    require(amount > 0, "amount is 0");
    require(isLive(listingId), "listing is not live");
    require(!listings[listingId].inactive, "cannnot purchase revoked/sold listing");

    Listing memory listing = listings[listingId];

    uint256 price = 0;

    console.log("Pruchasing");
    if (listing.fungible) {
      price = _purchase1155(listingId, amount);
    } else {
      price = _purchase721(listingId);
    }
    uint256 allowance = operatingToken.allowance(msg.sender, address(this));
    console.log("Allowance: %s: %s", address(this), allowance);

    // operatingToken.transferFrom(msg.sender, address(this), amount);
    console.log("Transferring tokens: %s", price);
    if (feeRate != 0) {
      uint256 fee = (price * feeRate) / 10_000;
      price = SafeMath.sub(price, fee);
      // Send the fee to the contract owner
      console.log(" > Fee: %s", fee);
      operatingToken.transferFrom(msg.sender, owner(), fee);
    }
    console.log(" > Listing Owner: %s: %s", price, listing.owner);
    operatingToken.transferFrom(msg.sender, listing.owner, price);

    console.log("Sold");
    emit Sold(listingId, msg.sender, amount);
  }
}
