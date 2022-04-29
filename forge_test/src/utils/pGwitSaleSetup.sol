// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BasicSetup} from "./BasicSetup.sol";
import {PreGwitSale} from "contracts/gwit/pGwitSale.sol";
import {PreGwit} from "contracts/gwit/pGwit.sol";
import {Auth} from "contracts/utils/Auth.sol";
import {MockUsdc} from "contracts/mocks/Usdc.sol";

contract PreGwitSaleSetup is BasicSetup {
  PreGwitSale pGwitSale;
  MockUsdc usdc;
  PreGwit pGwit;

  PreGwitSale.Sig zeroSig;
  bytes32 private constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  function setUp() public virtual {
    pGwit = new PreGwit();
    usdc = new MockUsdc();
    pGwitSale = new PreGwitSale(address(usdc), address(pGwit), vault);

    pGwit.grantRole("MINTER", address(pGwitSale));

    vm.label(address(pGwit), "pGwit");
    vm.label(address(usdc), "usdc");
    vm.label(address(pGwitSale), "pGwitSale");
  }

  function set() public virtual {
    uint32 time = uint32(block.timestamp);
    uint256 supply = 50_000_000e18;
    uint256 cap = 100_000e18;
    uint256 price = 50_000; //$0.05
    pGwitSale.set(time + 1 days, time + 2 days, supply, cap, price);
  }

  function gotoOpeningTime() public virtual {
    (uint32 openingTime, , , , , ) = pGwitSale.info();
    vm.warp(openingTime);
  }

  function gotoClosingTime() public virtual {
    (, uint32 closingTime, , , , ) = pGwitSale.info();
    vm.warp(closingTime);
  }

  function mintAndApproveUsdc(address to, uint256 pGwitAmount) public virtual {
    (, , , , , uint256 price) = pGwitSale.info();
    uint256 amount = (price * pGwitAmount) / 1e18;
    usdc.mint(to, amount);

    vm.prank(to);
    usdc.approve(address(pGwitSale), amount);
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
    (, , , , , uint256 price) = pGwitSale.info();
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
          keccak256(abi.encode(PERMIT_TYPEHASH, addr, address(pGwitSale), amount, nonce, deadline))
        )
      )
    );

    return (deadline, r, s, v);
  }

  function buy(address user, uint256 amount) public virtual {
    PreGwitSale.Sig memory sig = zeroSig;
    vm.prank(user);
    pGwitSale.buy(user, amount, 0, sig, bytes32(0));
  }

  function buyPermit(
    address user,
    uint256 amount,
    uint256 deadline,
    bytes32 r,
    bytes32 s,
    uint8 v
  ) public virtual {
    PreGwitSale.Sig memory sig = PreGwitSale.Sig(r, s, v);
    vm.prank(user);
    pGwitSale.buy(user, amount, deadline, sig, bytes32(0));
  }
}
