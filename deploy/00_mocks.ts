import { DeployFunction } from "hardhat-deploy/types";
import { MockUsdc__factory } from "../types";
import { toWei, Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, users } = await Ship.init(hre);
  const usdc = await deploy(MockUsdc__factory);
  if (usdc.newlyDeployed) {
    for (let i = 1; i < 10; i++) {
      const tx = await usdc.contract.transfer(users[i].address, toWei(1000, 6));
      await tx.wait();
    }
  }
};

export default func;
func.tags = ["mocks"];
