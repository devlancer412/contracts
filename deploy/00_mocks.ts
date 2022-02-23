import { DeployFunction } from "hardhat-deploy/types";
import { USDC__factory } from "../types";
import { toWei, Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, users } = await Ship.init(hre);
  const usdc = await deploy(USDC__factory);
  for (let i = 1; i < 10; i++) {
    await usdc.transfer(users[i].address, toWei(1000, 6));
  }
};

export default func;
func.tags = [""];
