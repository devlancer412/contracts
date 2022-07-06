import RouterAbi from "../.forge/IUniswapV2Router01.sol/IUniswapV2Router01.json";
import { ethers } from "hardhat";
import { MockDai__factory, MockUsdc__factory, MockUsdt__factory } from "../types";
import { Ship, toWei } from "../utils";
import { constants } from "ethers";

const main = async () => {
  const { connect, provider, accounts } = await Ship.init();
  const usdc = await connect(MockUsdc__factory);
  const dai = await connect(MockDai__factory);
  const usdt = await connect(MockUsdt__factory);
  const router = new ethers.Contract("0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506", RouterAbi.abi, provider);

  {
    console.log("set");
    await usdc.set(accounts.deployer.address, toWei(2_000_000_000, 6));
    await usdt.set(accounts.deployer.address, toWei(1_000_000_000, 6));
    await dai.set(accounts.deployer.address, toWei(1_000_000_000, 18));
  }

  {
    console.log("approve");
    const gasPrice = (await provider.getGasPrice()).mul(3).div(2);
    const tx1 = await usdc.approve(router.address, constants.MaxUint256, { gasPrice });
    const tx2 = await usdt.approve(router.address, constants.MaxUint256, { gasPrice });
    const tx3 = await dai.approve(router.address, constants.MaxUint256, { gasPrice });
    await Promise.all([tx1.wait(), tx2.wait(), tx3.wait()]);
  }

  {
    console.log("add");
    const gasPrice = (await provider.getGasPrice()).mul(3).div(2);
    await router
      .connect(accounts.deployer)
      .addLiquidity(
        usdc.address,
        dai.address,
        toWei(1_000_000_000, 6),
        toWei(1_000_000_000, 18),
        0,
        0,
        accounts.deployer.address,
        constants.MaxUint256,
        { gasPrice },
      );
    await router
      .connect(accounts.deployer)
      .addLiquidity(
        usdc.address,
        usdt.address,
        toWei(1_000_000_000, 6),
        toWei(1_000_000_000, 6),
        0,
        0,
        accounts.deployer.address,
        constants.MaxUint256,
        { gasPrice },
      );
  }
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
