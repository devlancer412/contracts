import { Affiliate__factory, MockUsdc__factory } from "../types";
import { DeployFunction } from "hardhat-deploy/types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect, accounts } = await Ship.init(hre);

  const usdc = await connect(MockUsdc__factory);

  await deploy(Affiliate__factory, {
    args: [usdc.address, accounts.signer.address],
  });
};

export default func;
func.tags = ["affiliate"];
func.dependencies = ["mocks"];
