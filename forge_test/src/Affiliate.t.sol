// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Affiliate} from "contracts/affiliate/Affiliate.sol";
import {RoosterEgg} from "contracts/egg/Egg.sol";
import {RoosterEggSale} from "contracts/egg/EggSale.sol";
import {GWITToken} from "contracts/gwit/gwit.sol";
import {Rooster} from "contracts/rooster/Rooster.sol";
import {Store} from "contracts/store/Store.sol";
import {MockUsdc} from "contracts/mocks/Usdc.sol";
import {Auth} from "contracts/utils/Auth.sol";
import "./utils/BasicSetup.sol";

interface IAffiliate {
  function buyEggWithAffiliate(
    address,
    uint256,
    address,
    address,
    uint32
  ) external;

  function buyItemWithAffiliate(
    address,
    uint256,
    uint256,
    address,
    address,
    uint32
  ) external;
}

contract AffiliateTest is BasicSetup {
  Affiliate affiliate;
  MockUsdc usdc;
  RoosterEgg egg;
  RoosterEggSale eggSale;
  GWITToken gwit;
  Rooster rooster;
  Store store;

  address constant grp = address(101);
  address constant farmPool = address(102);
  address constant taxRecipient = address(201);

  // utils

  //  utils
  function sign(
    address sender,
    address to,
    uint64[] memory codes,
    uint256 value
  )
    public
    virtual
    returns (
      bytes32,
      bytes32,
      uint8
    )
  {
    bytes32 messageHash = keccak256(abi.encodePacked(sender, to, codes, value));

    bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSecretKey, digest);
    return (r, s, v);
  }

  // test
  function setUp() public {
    usdc = new MockUsdc();
    affiliate = new Affiliate(address(usdc), signer);
    egg = new RoosterEgg(IERC20(address(usdc)), vault, 0, "asdf");
    eggSale = new RoosterEggSale(address(usdc), address(egg), vault, signer, 0);
    egg.transferOwnership(address(eggSale));
    eggSale.setAffiliateData(address(affiliate), 50);

    gwit = new GWITToken(1_000_000);
    gwit.init(grp, farmPool);
    gwit.setTaxAddress(taxRecipient);

    gwit.transfer(alice, 500);
    store = new Store(IERC20(address(gwit)), vault);
    store.setAffiliateAddress(address(affiliate));
    store.setAllowedLister(bob, true);

    rooster = new Rooster("");
    rooster.grantRole("MINTER", address(store));

    affiliate.grantRole("DISTRIBUTOR", signer);
    usdc.mint(signer, 10000);
    vm.prank(signer);
    usdc.approve(address(affiliate), 10000);
  }

  function testRedeem() public {
    uint64[] memory codes = new uint64[](4);
    codes[0] = 1;
    codes[1] = 2;
    codes[2] = 3;
    codes[3] = 4;

    uint256 value = 650;

    (bytes32 r, bytes32 s, uint8 v) = sign(alice, alice, codes, value);

    vm.prank(alice);
    affiliate.redeemCode(alice, codes, value, Affiliate.Sig(r, s, v));
    assertEq(usdc.balanceOf(signer), 9350);
    assertEq(usdc.balanceOf(alice), 650);
  }

  function testReCall() public {
    testRedeem();
    uint64[] memory codes = new uint64[](4);
    codes[0] = 1;
    codes[1] = 2;
    codes[2] = 3;
    codes[3] = 4;

    uint256 value = 650;

    (bytes32 r, bytes32 s, uint8 v) = sign(alice, alice, codes, value);

    vm.prank(alice);
    vm.expectRevert(bytes("Affiliate:ALREADY_REDEEMED"));
    affiliate.redeemCode(alice, codes, value, Affiliate.Sig(r, s, v));
  }

  function testBuyEggWithAffiliate() public {
    affiliate.setDistributor(vault);
    usdc.mint(alice, 500);
    vm.prank(alice);
    usdc.approve(address(eggSale), 500);
    vm.prank(alice);
    IAffiliate(address(affiliate)).buyEggWithAffiliate(
      alice,
      10,
      address(eggSale),
      bob,
      uint32(RoosterEggSale.buyEggWithAffiliate.selector)
    );

    assertEq(usdc.balanceOf(alice), 0);
    assertEq(egg.balanceOf(alice), 10);
    assertEq(usdc.balanceOf(vault), 500);
  }

  function testBuyItemWithAffiliate() public {
    Store.TokenType tokenType = Store.TokenType.ERC721EXT; // ERC721EX
    address tokenAddress = address(rooster);
    uint256 tokenId = 0; // Only for ERC1155 use
    uint256 amount = 1; // Only mint 1 egg
    uint256 price = 500; // each mint costs 100 of the operating token
    uint256 maxval = 10; // the maximum value to pass to the unique parameter, leave to 0 to send a random uint256 value [0x00_00...00, 0xFF_FF...FF];
    vm.prank(bob);
    store.makeListing(tokenType, tokenAddress, tokenId, amount, price, maxval);

    uint256 listingId = 1;

    vm.prank(alice);
    gwit.approve(address(store), 500);
    vm.prank(alice);
    IAffiliate(address(affiliate)).buyItemWithAffiliate(
      alice,
      listingId,
      1,
      address(store),
      bob,
      uint32(Store.buyItemWithAffiliate.selector)
    );

    assertEq(gwit.balanceOf(alice), 0);
    assertEq(rooster.balanceOf(alice), 1);
    assertEq(gwit.balanceOf(bob), 500);
  }
}
