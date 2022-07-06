import { DeployFunction } from "hardhat-deploy/types";
import { MockDai__factory, MockUsdc__factory, MockUsdt__factory, QBuxVault__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect, accounts, provider } = await Ship.init(hre);

  if (hre.network.name === "rinkeby") {
    const usdc = await connect(MockUsdc__factory);
    const dai = await connect(MockDai__factory);
    const usdt = await connect(MockUsdt__factory);
    const { contract: qbux } = await deploy(QBuxVault__factory, {
      args: [usdc.address, accounts.vault.address, "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506", 1],
    });
    await qbux.setApprovedToken(usdc.address, true);
    await qbux.setApprovedToken(dai.address, true);
    await qbux.setApprovedToken(usdt.address, true);
  } else if (hre.network.name === "polygon") {
    const usdc = await connect(MockUsdc__factory, "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174");
    const dai = await connect(MockDai__factory, "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063");
    const usdt = await connect(MockUsdt__factory, "0xc2132D05D31c914a87C6611C10748AEb04B58e8F");
    const { contract: qbux } = await deploy(QBuxVault__factory, {
      args: [
        usdc.address,
        "0x3Fc30f1C68B9AA344F81B57F5bf813af77E51E0b",
        "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
        200,
      ],
    });
    const gasPrice = (await provider.getGasPrice()).mul(2);
    await qbux.setApprovedToken(usdc.address, true, { gasPrice });
    await qbux.setApprovedToken(dai.address, true, { gasPrice });
    await qbux.setApprovedToken(usdt.address, true, { gasPrice });
    await qbux.setWithdrawFees(accounts.vault.address, 500, { gasPrice });
  }
};

export default func;
func.tags = ["qbux"];
// func.dependencies = ["mocks"];
