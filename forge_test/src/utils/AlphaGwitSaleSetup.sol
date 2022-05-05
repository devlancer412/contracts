// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BasicSetup} from "./BasicSetup.sol";
import {AlphaGwitSale} from "contracts/gwit/AlphaGwitSale.sol";
import {AlphaGwit} from "contracts/gwit/AlphaGwit.sol";
import {Auth} from "contracts/utils/Auth.sol";
import {MockUsdc} from "contracts/mocks/Usdc.sol";

contract AlphaGwitSaleSetup is BasicSetup {
  AlphaGwitSale aGwitSale;
  MockUsdc usdc;
  AlphaGwit aGwit;

  AlphaGwitSale.Sig zeroSig;
  bytes32 private constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  function setUp() public virtual {
    aGwit = new AlphaGwit();
    usdc = new MockUsdc();
    aGwitSale = new AlphaGwitSale(address(usdc), address(aGwit), vault);

    aGwit.grantRole("MINTER", address(aGwitSale));

    vm.label(address(aGwit), "aGWIT");
    vm.label(address(usdc), "USDC");
    vm.label(address(aGwitSale), "AlphaGwitSale");
  }

  function set() public virtual {
    uint32 time = uint32(block.timestamp);
    uint256 supply = 50_000_000e18;
    uint256 cap = 100_000e18;
    uint256 price = 50_000; //$0.05
    aGwitSale.set(time + 1 days, time + 2 days, supply, cap, price);
  }

  function gotoOpeningTime() public virtual {
    (uint32 openingTime, , , , , ) = aGwitSale.info();
    vm.warp(openingTime);
  }

  function gotoClosingTime() public virtual {
    (, uint32 closingTime, , , , ) = aGwitSale.info();
    vm.warp(closingTime);
  }

  function mintAndApproveUsdc(address to, uint256 pGwitAmount) public virtual {
    (, , , , , uint256 price) = aGwitSale.info();
    uint256 amount = (price * pGwitAmount) / 1e18;
    usdc.mint(to, amount);

    vm.prank(to);
    usdc.approve(address(aGwitSale), amount);
  }

  function mintAndPermitUsdc(uint256 pk, uint256 pGwitAmount)
    public
    virtual
    returns (
      uint256,
      bytes32,
      bytes32,
      uint8
    )
  {
    address addr = vm.addr(pk);
    (, , , , , uint256 price) = aGwitSale.info();
    uint256 amount = (price * pGwitAmount) / 1e18;
    usdc.mint(addr, amount);

    uint256 nonce = usdc.nonces(addr);
    uint256 deadline = block.timestamp + 60 seconds;
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      pk,
      keccak256(
        abi.encodePacked(
          "\x19\x01",
          usdc.DOMAIN_SEPARATOR(),
          keccak256(abi.encode(PERMIT_TYPEHASH, addr, address(aGwitSale), amount, nonce, deadline))
        )
      )
    );

    return (deadline, r, s, v);
  }

  function buy(address user, uint256 amount) public virtual {
    AlphaGwitSale.Sig memory sig = zeroSig;
    vm.prank(user);
    aGwitSale.buy(user, amount, 0, sig, bytes32(0));
  }

  function buyPermit(
    address user,
    uint256 amount,
    uint256 deadline,
    bytes32 r,
    bytes32 s,
    uint8 v
  ) public virtual {
    AlphaGwitSale.Sig memory sig = AlphaGwitSale.Sig(r, s, v);
    vm.prank(user);
    aGwitSale.buy(user, amount, deadline, sig, bytes32(0));
  }
}
