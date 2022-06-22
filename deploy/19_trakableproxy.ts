import { TrackableProxy__factory, MockUsdc__factory } from "../types";
import { DeployFunction } from "hardhat-deploy/types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect, accounts } = await Ship.init(hre);

  await deploy(TrackableProxy__factory, {
    args: [],
  });
};

export default func;
func.tags = ["trackableproxy"];
