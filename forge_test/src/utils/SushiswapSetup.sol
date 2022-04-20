// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {IUniswapV2Factory} from "sushiswap/uniswapv2/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "sushiswap/uniswapv2/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "sushiswap/uniswapv2/interfaces/IUniswapV2Pair.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {GWITToken} from "contracts/gwit/gwit.sol";
import {BasicSetup} from "./BasicSetup.sol";

contract SushiswapSetup is BasicSetup {
  IUniswapV2Factory factory;
  IUniswapV2Router02 router;
  IUniswapV2Pair pair;
  ERC20 mock;
  GWITToken gwit;
  uint256 TAX;

  uint256 public constant MAX = type(uint256).max;

  function setUp() public virtual {
    vm.label(address(gwit), "gwit");

    bytes memory args1 = abi.encode(address(this));
    address factoryAddr = deployCode(
      "forge_test/lib/sushiswap/artifacts/contracts/uniswapv2/UniswapV2Factory.sol/UniswapV2Factory.json",
      args1
    );
    vm.label(factoryAddr, "factory");
    factory = IUniswapV2Factory(factoryAddr);

    address wethAddr = deployCode(
      "forge_test/lib/sushiswap/artifacts/contracts/mocks/WETH9Mock.sol/WETH9Mock.json",
      bytes("")
    );
    vm.label(wethAddr, "weth");

    bytes memory args2 = abi.encode(factoryAddr, wethAddr);
    address routerAddr = deployCode(
      "forge_test/lib/sushiswap/artifacts/contracts/uniswapv2/UniswapV2Router02.sol/UniswapV2Router02.json",
      args2
    );
    vm.label(routerAddr, "router");
    router = IUniswapV2Router02(routerAddr);

    mock = new ERC20("mock", "MOCK");
    vm.label(address(mock), "mock");
  }

  function setMockBalance(address to, uint256 amount) public {
    _setBalance(address(mock), to, amount);
  }

  function setGwitBalance(address to, uint256 amount) public {
    _setBalance(address(gwit), to, amount);
  }

  function _setBalance(
    address token,
    address to,
    uint256 amount
  ) private {
    uint256 balancesSlot = 0;
    bytes32 userKey = bytes32(uint256(uint160(to)));
    bytes32 userBalanceSlot = bytes32(keccak256(abi.encodePacked(userKey, balancesSlot)));
    bytes32 value = bytes32(amount);
    vm.store(token, userBalanceSlot, value);
  }

  function addLiquidity(uint256 gwitAmount, uint256 mockTokenAmount) public virtual {
    address pairAddr = factory.createPair(address(mock), address(gwit));
    vm.label(pairAddr, "pair");
    pair = IUniswapV2Pair(pairAddr);
    gwit.setTaxRate(address(pair), TAX);

    setGwitBalance(address(this), gwitAmount);
    setMockBalance(address(this), mockTokenAmount);

    mock.approve(address(router), MAX);
    gwit.approve(address(router), MAX);

    router.addLiquidity(
      address(mock),
      address(gwit),
      mockTokenAmount,
      gwitAmount,
      0,
      0,
      address(this),
      MAX
    );
  }

  function buyGwit(address user, uint256 amountToBuy) public virtual {
    address[] memory path = new address[](2);
    path[0] = address(mock);
    path[1] = address(gwit);

    try router.getAmountsIn(amountToBuy, path) returns (uint256[] memory amounts) {
      vm.assume(amounts[0] < type(uint112).max && amounts[1] < type(uint112).max);

      setMockBalance(user, amounts[0]);

      vm.startPrank(user);
      mock.approve(address(router), amounts[0]);
      router.swapTokensForExactTokens(amountToBuy, amounts[0], path, user, MAX);
      vm.stopPrank();
    } catch {
      vm.assume(false);
    }
  }

  function sellGwit(address user, uint256 amountToSell) public virtual {
    address[] memory path = new address[](2);
    path[0] = address(gwit);
    path[1] = address(mock);

    uint256 amountIn = amountToSell - (amountToSell * TAX) / 10_000;

    try router.getAmountsOut(amountIn, path) returns (uint256[] memory amounts) {
      vm.assume(amounts[0] < type(uint112).max && amounts[1] < type(uint112).max);
      vm.assume(amounts[1] > 0);

      setGwitBalance(user, amountToSell);

      vm.startPrank(user);
      gwit.approve(address(router), amountToSell);
      router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        amountToSell,
        amounts[1],
        path,
        user,
        MAX
      );
      vm.stopPrank();
    } catch {
      vm.assume(false);
    }
  }
}
