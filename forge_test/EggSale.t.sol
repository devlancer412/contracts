// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./utils/EggSaleSetup.sol";

contract EggSaleTest is EggSaleSetup {
  event MaticCashbackFailed(address indexed user, uint256 balance);

  function setUp() public override {
    super.setUp();
  }

  function testForkIsWorking() public {
    assertTrue(egg.isOpen() == false);
    assertEq(egg.sold(), 943);
  }

  function testIsOpenWhenClosed() public {
    assertTrue(eggsale.isOpen() == false);
  }

  function testIsOpenWhenOpen() public {
    setNonWhitelistSale();
    gotoOpeningTime();
    assertTrue(eggsale.isOpen() == true);
  }

  function testMintEggs() public {
    eggsale.grantMinterRole(address(this));
    eggsale.mintEggs(alice, 10);
    assertEq(eggsale.minted(), mintedInit + 10);
    assertEq(egg.balanceOf(alice), 10);
  }

  function testCannotMintIfNotMinter() public {
    vm.expectRevert(bytes("Only minter"));
    eggsale.mintEggs(alice, 10);
  }

  function testSetBaseUri() public {
    eggsale.setBaseURI("hello");
    assertEq(keccak256(abi.encodePacked(egg.baseURI())), keccak256(abi.encodePacked("hello")));
  }

  function testCannotSetBaseUriIfNotOwner() public {
    vm.prank(alice);
    vm.expectRevert(bytes("Only owner"));
    eggsale.setBaseURI("hello");
  }

  function testDepositMatic() public {
    payable(address(eggsale)).transfer(1 ether);
  }

  function testWithdrawMatic() public {
    testDepositMatic();
    eggsale.withdrawMatic(1 ether);
    assertEq(vault.balance, 1 ether);
  }

  function testCannotWithdrawMaticIfNotOwner() public {
    testDepositMatic();
    vm.prank(alice);
    vm.expectRevert(bytes("Only owner"));
    eggsale.withdrawMatic(1 ether);
  }

  function testTransferEggOwnership() public {
    eggsale.transferEggContractOwnership(alice);
    assertEq(egg.owner(), alice);
  }

  function testCannnotTransferEggOwnershipIfNotOwner() public {
    vm.prank(alice);
    vm.expectRevert(bytes("Only owner"));
    eggsale.transferEggContractOwnership(alice);
  }

  function testSetEggSale() public {
    uint32 time = uint32(block.timestamp) + 10;
    eggsale.setEggSale(time, time + 2 days, 1000, 10, true, 30 * 10e6, 45000000000000000);

    (
      uint32 supply,
      uint32 cap,
      uint32 sold,
      uint32 openingTime,
      uint32 closingTime,
      bool whitelist,
      uint256 price,
      uint256 cashback
    ) = eggsale.eggsale();

    assertEq(supply, 1000);
    assertEq(cap, 10);
    assertEq(sold, 0);
    assertEq(openingTime, time);
    assertEq(closingTime, time + 2 days);
    assertTrue(whitelist);
    assertEq(price, 30 * 10e6);
    assertEq(cashback, 45000000000000000);
  }

  function testSetEggSaleDuringSale() public {
    uint32 time = uint32(block.timestamp) + 10;
    eggsale.setEggSale(time, time + 2 days, 1000, 10, true, 30 * 10e6, 45000000000000000);
    gotoOpeningTime();

    uint32 time2 = uint32(block.timestamp);
    eggsale.setEggSale(time2, time2 + 1 days, 10000, 20, true, 45 * 10e6, 0);

    (
      uint32 supply,
      uint32 cap,
      uint32 sold,
      uint32 openingTime,
      uint32 closingTime,
      bool whitelist,
      uint256 price,
      uint256 cashback
    ) = eggsale.eggsale();

    assertEq(supply, 10000);
    assertEq(cap, 20);
    assertEq(sold, 0);
    assertEq(openingTime, time);
    assertEq(closingTime, time2 + 1 days);
    assertTrue(whitelist);
    assertEq(price, 45 * 10e6);
    assertEq(cashback, 0);
  }

  function testCannotSetEggSaleIfNotOwner() public {
    vm.prank(alice);
    vm.expectRevert(bytes("Only owner"));
    eggsale.setEggSale(0, 0, 0, 0, false, 0, 0);
  }

  function testBuyEggsFromNonWhitelistSale(uint8 amount) public {
    if (amount > 10) return;

    setNonWhitelistSale();
    depositMaticForCashback();
    gotoOpeningTime();

    mintAndApproveUsdcForEggSale(alice, amount);
    RoosterEggSale.Sig memory sig = zeroSig;
    vm.prank(alice);
    eggsale.buyEggs(amount, bytes32(0), sig);

    (, , uint32 sold, , , , , ) = eggsale.eggsale();
    assertEq(egg.balanceOf(alice), amount);
    assertEq(sold, amount);
    assertEq(eggsale.minted(), mintedInit + amount);
    assertEq(alice.balance, uint256(45000000000000000) * amount);
    assertEq(eggsale.purchasedAmount(alice), amount);
  }

  function testBuyEggsFromWhitelistSale(uint8 amount) public {
    if (amount > 10) return;

    setWhitelistSale();
    depositMaticForCashback();
    gotoOpeningTime();

    mintAndApproveUsdcForEggSale(alice, amount);
    (bytes32 nonce, bytes32 r, bytes32 s, uint8 v) = sign(alice);
    RoosterEggSale.Sig memory sig = RoosterEggSale.Sig(r, s, v);
    vm.prank(alice);
    eggsale.buyEggs(amount, nonce, sig);

    (, , uint32 sold, , , , , ) = eggsale.eggsale();
    assertEq(egg.balanceOf(alice), amount);
    assertEq(sold, amount);
    assertEq(eggsale.minted(), mintedInit + amount);
    assertEq(alice.balance, uint256(45000000000000000) * amount);
    assertEq(eggsale.purchasedAmount(alice), amount);
  }

  function testBuyEggsWithoutMaticCashback(uint8 amount) public {
    if (amount > 10 || amount == 0) return;

    setNonWhitelistSale();
    gotoOpeningTime();

    mintAndApproveUsdcForEggSale(alice, amount);
    vm.expectEmit(true, false, false, true);
    emit MaticCashbackFailed(alice, 0);
    buyEggs(alice, amount);
  }

  function testCannotBuyIfNotOpen() public {
    setNonWhitelistSale();
    vm.expectRevert(bytes("Not open"));

    buyEggs(alice, 2);
  }

  function testCannotBuyIfPaused() public {
    setNonWhitelistSale();
    eggsale.pause();

    vm.expectRevert(bytes("Pausable: paused"));
    buyEggs(alice, 2);
  }

  function testCannotBuyIfItExceedsMaxSupply() public {
    setNonWhitelistSale();
    depositMaticForCashback();
    gotoOpeningTime();

    //Modify total minted
    bytes32 mintedSlot = bytes32(uint256(6));
    bytes32 newMinted = bytes32(uint256(150_000 - 1));
    vm.store(address(eggsale), mintedSlot, newMinted);

    vm.expectRevert(bytes("Exceeds max supply"));
    buyEggs(alice, 2);
  }

  function testCannotBuyIfItExceedsSupply() public {
    setNonWhitelistSale();
    depositMaticForCashback();
    gotoOpeningTime();

    //Modify supply
    (uint32 supply, uint32 cap, , uint32 openingTime, uint32 closingTime, , , ) = eggsale.eggsale();
    bytes32 eggsaleSlot = bytes32(uint256(3));
    bytes32 newEggSale = bytes32(
      abi.encodePacked(
        bytes11(0),
        bool(false),
        uint32(closingTime),
        uint32(openingTime),
        uint32(supply - 1),
        uint32(cap),
        uint32(supply)
      )
    );
    vm.store(address(eggsale), eggsaleSlot, newEggSale);

    vm.expectRevert(bytes("Exceeds supply"));
    buyEggs(alice, 2);
  }

  function testCannotBuyIfItExceedsCap(uint8 amount) public {
    if (amount <= 10) return;

    setNonWhitelistSale();
    depositMaticForCashback();
    gotoOpeningTime();

    vm.expectRevert(bytes("Exceeds cap"));
    buyEggs(alice, amount);
  }

  function testCannotBuyIfItExceedsCapIncludingPreviousSale(uint8 amount1, uint8 amount2) public {
    if (amount1 > 10 || uint256(amount1) + amount2 <= 10) return;

    //Modify purchased amount vaule in egg contract
    uint256 purchasedAmountSlot = 11;
    bytes32 userKey = bytes32(uint256(uint160(alice)));
    bytes32 userPurchasedAmountSlot = bytes32(
      keccak256(abi.encodePacked(userKey, purchasedAmountSlot))
    );
    bytes32 value = bytes32(abi.encode(uint8(amount1)));
    vm.store(address(egg), userPurchasedAmountSlot, value);

    setNonWhitelistSale();
    depositMaticForCashback();
    gotoOpeningTime();

    vm.expectRevert(bytes("Exceeds cap"));
    buyEggs(alice, amount2);
  }

  function testCannotBuyIfSameNonceIsPassedInWhitelistSale() public {
    setWhitelistSale();
    depositMaticForCashback();
    gotoOpeningTime();

    uint8 amount = 3;
    mintAndApproveUsdcForEggSale(alice, amount * 2);
    (bytes32 nonce, bytes32 r, bytes32 s, uint8 v) = sign(alice);
    RoosterEggSale.Sig memory sig = RoosterEggSale.Sig(r, s, v);

    vm.prank(alice);
    eggsale.buyEggs(amount, nonce, sig);

    vm.prank(alice);
    vm.expectRevert(bytes("Nonce used"));
    eggsale.buyEggs(amount, nonce, sig);
  }

  function testCannotBuyIfNotWhitelistedInWhitelistSale() public {
    setWhitelistSale();
    depositMaticForCashback();
    gotoOpeningTime();

    uint8 amount = 3;
    mintAndApproveUsdcForEggSale(alice, amount);
    (bytes32 nonce, bytes32 r, bytes32 s, uint8 v) = sign(bob);
    RoosterEggSale.Sig memory sig = RoosterEggSale.Sig(r, s, v);

    vm.prank(alice);
    vm.expectRevert(bytes("Not whitelisted"));
    eggsale.buyEggs(amount, nonce, sig);
  }
}
