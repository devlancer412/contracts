pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Marketplace is Ownable {
  IERC20 public operatingToken;
  uint256 public feeRate;

  struct Listing {
    address operator;
    uint256 tokenId;
    uint256 cost;
    address owner;
    bool fungible;
    bool inactive;
  }

  uint256 public counter;
  mapping(uint256 => Listing) public listings;
  mapping(uint256 => uint256) public stocks;

  event Listed(
    uint256 listingId,
    address operator,
    uint256 tokenId,
    address indexed owner,
    uint256 amount
  );
  event Live(uint256 listingId);
  event Sold(uint256 listingId, address indexed owner, uint256 amount);
  event Revoke(uint256 listingId);

  constructor(IERC20 _operatingToken, uint256 _fee) {
    operatingToken = _operatingToken;
    feeRate = _fee;
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata
  ) public returns (bytes4) {
    counter += 1;
    listings[counter] = Listing(operator, tokenId, 0, from, false, false);
    emit Listed(counter, operator, tokenId, from, 1);
    return this.onERC721Received.selector;
  }

  function onERC1155Received(
    address operator,
    address from,
    uint256 id,
    uint256 value,
    bytes calldata
  ) public returns (bytes4) {
    counter += 1;
    listings[counter] = Listing(operator, id, 0, from, true, false);
    stocks[counter] = value;
    emit Listed(counter, operator, id, from, value);
    return this.onERC1155Received.selector;
  }

  function setLive(uint256 listingId, uint256 cost) public {
    require(listings[listingId].owner == msg.sender, "only owner can set the listing as live");
    require(!listings[listingId].inactive, "cannnot reactivate revoked/sold listing");

    listings[listingId].cost = cost;
    emit Live(listingId);
  }

  function isLive(uint256 listingId) public view returns (bool) {
    return listings[listingId].cost != 0;
  }

  function revoke(uint256 listingId) public {
    require(listings[listingId].owner == msg.sender, "only owner can revoke the listing");
    require(!listings[listingId].inactive, "cannnot revoke revoked/sold listing");

    if (listings[listingId].fungible) {} else {
      IERC721 op = IERC721(listings[listingId].operator);
      op.safeTransferFrom(address(this), msg.sender, listings[listingId].tokenId);
      listings[listingId].inactive = true;
    }

    emit Revoke(listingId);
  }

  function purchase(uint256 listingId, uint256 amount) public {
    require(amount > 0, "amount is 0");
    require(listings[listingId].cost != 0, "listing is not live");
    require(!listings[listingId].inactive, "cannnot purchase revoked/sold listing");

    uint256 cost = listings[listingId].cost;

    // if ERC1155 token
    if (listings[listingId].fungible) {
      require(stocks[listingId] != 0, "listing not in stock");
      require(stocks[listingId] >= amount, "not enough in stock");
      cost = SafeMath.mul(cost, amount);
      stocks[listingId] = SafeMath.sub(stocks[listingId], amount);
    } else {
      require(amount == 1, "cannot buy multiple of the same nft");
    }

    require(
      operatingToken.allowance(msg.sender, address(this)) >= cost,
      "not enough funds allocated"
    );

    if (feeRate != 0) {
      uint256 fee = SafeMath.div(SafeMath.mul(cost, feeRate), 10_000);
      cost = SafeMath.sub(cost, fee);
      // Send the fee to the contract owner
      operatingToken.transferFrom(msg.sender, owner(), fee);
    }
    operatingToken.transferFrom(msg.sender, listings[listingId].owner, cost);

    if (stocks[listingId] == 0) {
      listings[listingId].inactive = true;
    }

    emit Sold(listingId, msg.sender, amount);
  }
}
