import { DeployFunction } from "hardhat-deploy/types";
import { RoosterEgg__factory, MockUsdc__factory, GWITToken__factory, GRP__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, users } = await Ship.init(hre);

  if (hre.network.tags.prod) {
    await deploy(GRP__factory, {
      args: [users[0].address],
    });
  } else {
    await deploy(GRP__factory, {
      args: [users[0].address],
    });
  }
};

export default func;
func.tags = ["grp"];
