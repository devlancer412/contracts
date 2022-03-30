// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {RoosterEgg} from "contracts/Egg.sol";
import {RoosterEggSale} from "contracts/EggSale.sol";
import {MockUsdc} from "contracts/mocks/Usdc.sol";
import "./BasicSetup.sol";

contract EggSaleSetup is BasicSetup {
  RoosterEggSale eggsale;
  RoosterEgg egg;
  MockUsdc usdc;

  RoosterEggSale.Sig zeroSig;
  uint256 mintedInit = 7172;
  uint256 nonceCounter = 0;

  function setUp() public virtual {
    usdc = new MockUsdc();
    egg = RoosterEgg(payable(0xbDD4AE46B65977a1d06b365c09B4e0F429c70Aef));
    eggsale = new RoosterEggSale(address(usdc), address(egg), vault, signer, mintedInit);

    address eggOwner = egg.owner();
    vm.prank(eggOwner);
    egg.transferOwnership(address(eggsale));
  }

  function depositMaticForCashback() public virtual {
    payable(address(eggsale)).transfer(100 ether);
  }

  function setNonWhitelistSale() public virtual {
    uint32 time = uint32(block.timestamp) + 10;
    eggsale.setEggSale(time, time + 2 days, 142828, 10, false, 30 * 10e6, 45000000000000000);
  }

  function setWhitelistSale() public virtual {
    uint32 time = uint32(block.timestamp) + 10;
    eggsale.setEggSale(time, time + 2 days, 142828, 10, true, 30 * 10e6, 45000000000000000);
  }

  function mintAndApproveUsdcForEggSale(address to, uint256 eggAmount) public virtual {
    (, , , , , , uint256 price, ) = eggsale.eggsale();
    uint256 amount = price * eggAmount;
    usdc.mint(to, amount);

    vm.prank(alice);
    usdc.approve(address(eggsale), type(uint256).max);
  }

  function gotoOpeningTime() public virtual {
    (, , , uint32 openingTime, , , , ) = eggsale.eggsale();
    vm.warp(openingTime);
  }

  function gotoClosingTime() public virtual {
    (, , , , uint32 closingTime, , , ) = eggsale.eggsale();
    vm.warp(closingTime);
  }

  function sign(address user)
    public
    virtual
    returns (
      bytes32,
      bytes32,
      bytes32,
      uint8
    )
  {
    bytes32 nonce = keccak256(abi.encodePacked(nonceCounter++));
    bytes32 messageHash = keccak256(abi.encodePacked(user, nonce));
    bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSecretKey, digest);
    return (nonce, r, s, v);
  }

  function buyEggs(address user, uint8 amount) public virtual {
    RoosterEggSale.Sig memory sig = zeroSig;
    vm.prank(user);
    eggsale.buyEggs(amount, bytes32(0), sig);
  }

  function buyEggsWithSignature(address user, uint8 amount) public virtual {
    (bytes32 nonce, bytes32 r, bytes32 s, uint8 v) = sign(user);
    RoosterEggSale.Sig memory sig = RoosterEggSale.Sig(r, s, v);
    vm.prank(user);
    eggsale.buyEggs(amount, nonce, sig);
  }
}
