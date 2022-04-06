import { BigNumber } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";
import { GRP__factory, GWITToken__factory, Marketplace__factory, MasterChef__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect } = await Ship.init(hre);

  const gwit = await connect(GWITToken__factory);
  await deploy(Marketplace__factory, {
    args: [gwit.address, 0],
  });
};

export default func;
func.tags = ["marketplace"];
