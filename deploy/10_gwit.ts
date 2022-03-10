import { BigNumber } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";
import { RoosterEgg__factory, MockUsdc__factory, GWITToken__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy } = await Ship.init(hre);
  const supply_size = BigNumber.from("1_000_000_000".replaceAll("_", ""));

  if (hre.network.tags.prod) {
    await deploy(GWITToken__factory, {
      args: [supply_size],
    });
  } else {
    await deploy(GWITToken__factory, {
      args: [supply_size],
    });
  }
};

export default func;
func.tags = ["gwit"];
