// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {PreGwit} from "contracts/gwit/pGwit.sol";
import {Auth} from "contracts/utils/Auth.sol";
import "./utils/BasicSetup.sol";

contract pGwitTest is BasicSetup {
  PreGwit pGwit;

  function setUp() public {
    pGwit = new PreGwit();
  }

  function testInit() public {
    assertEq(pGwit.name(), "PreGwit");
    assertEq(pGwit.symbol(), "pGWIT");
    assertEq(pGwit.decimals(), 18);
    assertEq(pGwit.totalSupply(), 0);
  }

  function testMint(address to, uint256 amount) public {
    vm.assume(to != address(0) && to != address(this));
    pGwit.grantRole("MINTER", address(this));
    pGwit.mint(to, amount);
    assertEq(pGwit.balanceOf(to), amount);
    assertEq(pGwit.totalSupply(), amount);
  }

  function testCannotMintIfNotMinter(address user) public {
    vm.prank(user);
    vm.expectRevert(abi.encodeWithSelector(Auth.Unauthorized.selector, "MINTER", user));
    pGwit.mint(address(0xbeef), 1e18);
  }

  function testBurn(address user, uint256 amount) public {
    vm.assume(amount % 2 == 0);

    //Mint
    pGwit.grantRole("MINTER", address(this));
    pGwit.mint(user, amount);

    //Burn
    vm.prank(user);
    pGwit.burn(amount / 2);
    assertEq(pGwit.balanceOf(user), amount / 2);
  }
}
