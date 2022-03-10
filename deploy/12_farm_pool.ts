import { BigNumber } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";
import { GWITToken__factory, MasterChef__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, users, connect } = await Ship.init(hre);

  const startBlock = 10;
  const gwitPerBlock = BigNumber.from("100" + "000000000000000000");
  const bonusEndBlock = startBlock + 100;
  const gwit = await connect(GWITToken__factory);

  if (hre.network.tags.prod) {
    await deploy(MasterChef__factory, {
      args: [gwit.address, users[0].address, gwitPerBlock, bonusEndBlock, startBlock],
    });
  } else {
    await deploy(MasterChef__factory, {
      args: [gwit.address, users[0].address, gwitPerBlock, bonusEndBlock, startBlock],
    });
  }
};

export default func;
func.tags = ["grp"];
