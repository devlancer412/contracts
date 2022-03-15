pragma solidity ^0.8.0;

/**
  Marketplace spec: https://www.notion.so/RoosterWars-Marketplace-6350187ee37f4e239aa8441b7e634e00
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Marketplace is Ownable {
  IERC20 public operatingToken;
  uint256 public feeRate;

  struct Listing {
    address token;
    uint256 tokenId;
    uint256 cost;
    address owner;
    bool fungible;
    bool inactive;
  }

  uint256 public counter;
  // { listingId: Listing}
  mapping(uint256 => Listing) public listings;
  // { listingId: inStock }
  mapping(uint256 => uint256) public stocks;
  // { contractAddress: allowed }
  mapping(address => bool) public allowedContracts;
  // { contractAddress: { tokenId: ownerAddress } }
  mapping(address => mapping(uint256 => address)) public transfers;

  // { contractAddress: { tokenId: { ownerAddress: amount } } }
  mapping(address => mapping(uint256 => mapping(address => uint256))) public fungibleTransfers;

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
      uint256 cost,
      address owner,
      bool fungible,
      bool inactive
    )
  {
    token = listings[listingId].token;
    tokenId = listings[listingId].tokenId;
    cost = listings[listingId].cost;
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
    require(allowedContracts[msg.sender], "operator not allowed");
    transfers[msg.sender][tokenId] = from;
    return this.onERC721Received.selector;
  }

  function onERC1155Received(
    address,
    address from,
    uint256 tokenId,
    uint256 amount,
    bytes calldata
  ) public returns (bytes4) {
    require(allowedContracts[msg.sender], "operator not allowed");
    fungibleTransfers[msg.sender][tokenId][from] = amount;
    return this.onERC1155Received.selector;
  }

  function makeListing(
    address token,
    uint256 tokenId,
    uint256 amount,
    uint256 price,
    bool fungible
  ) public returns (uint256) {
    uint256 id = counter;
    if (fungible) {
      uint256 balance = fungibleTransfers[token][tokenId][msg.sender];
      require(balance >= amount, "not enough tokens to create listing");
      stocks[id] = amount;
      fungibleTransfers[token][tokenId][msg.sender] -= amount;
    } else {
      require(
        IERC721(token).ownerOf(tokenId) == address(this),
        "nft not transfered to marketplace"
      );
    }

    listings[id] = Listing(token, tokenId, price, msg.sender, fungible, false);

    counter += 1;

    emit Listed(id, token, tokenId, msg.sender, amount, price);
    return id;
  }

  function setCost(uint256 listingId, uint256 cost) public {
    require(listings[listingId].owner == msg.sender, "only owner can set the listing as live");
    require(!listings[listingId].inactive, "cannnot reactivate revoked/sold listing");

    listings[listingId].cost = cost;
    emit Live(listingId);
  }

  function isLive(uint256 listingId) public view returns (bool) {
    return listings[listingId].cost != 0;
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
        fungibleTransfers[listings[listingId].token][listings[listingId].tokenId][msg.sender],
        ""
      );
      fungibleTransfers[listings[listingId].token][listings[listingId].tokenId][msg.sender] = 0;
    } else {
      IERC721 op = IERC721(listings[listingId].token);
      op.safeTransferFrom(address(this), msg.sender, listings[listingId].tokenId);
      listings[listingId].inactive = true;
    }

    emit Revoke(listingId);
  }

  function purchase(uint256 listingId, uint256 amount) public {
    require(amount > 0, "amount is 0");
    require(isLive(listingId), "listing is not live");
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
