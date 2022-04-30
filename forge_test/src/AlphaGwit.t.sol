// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {AlphaGwit} from "contracts/gwit/AlphaGwit.sol";
import {Auth} from "contracts/utils/Auth.sol";
import "./utils/BasicSetup.sol";

contract AlphaGwitTest is BasicSetup {
  AlphaGwit aGwit;

  function setUp() public {
    aGwit = new AlphaGwit();
  }

  function testInit() public {
    assertEq(aGwit.name(), "AlphaGwit");
    assertEq(aGwit.symbol(), "aGWIT");
    assertEq(aGwit.decimals(), 18);
    assertEq(aGwit.totalSupply(), 0);
  }

  function testMint(address to, uint256 amount) public {
    vm.assume(to != address(0) && to != address(this));
    aGwit.grantRole("MINTER", address(this));
    aGwit.mint(to, amount);
    assertEq(aGwit.balanceOf(to), amount);
    assertEq(aGwit.totalSupply(), amount);
  }

  function testCannotMintIfNotMinter(address user) public {
    vm.prank(user);
    vm.expectRevert(abi.encodeWithSelector(Auth.Unauthorized.selector, "MINTER", user));
    aGwit.mint(address(0xbeef), 1e18);
  }

  function testBurn(address user, uint256 amount) public {
    vm.assume(amount % 2 == 0);

    //Mint
    aGwit.grantRole("MINTER", address(this));
    aGwit.mint(user, amount);

    //Burn
    vm.prank(user);
    aGwit.burn(amount / 2);
    assertEq(aGwit.balanceOf(user), amount / 2);
  }
}
