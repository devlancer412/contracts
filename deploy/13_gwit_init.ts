import { BigNumber } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";
import { GRP__factory, GWITToken__factory, MasterChef__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { connect } = await Ship.init(hre);

  const grp = await connect(GRP__factory);
  const gwit = await connect(GWITToken__factory);
  const farm_pool = await connect(MasterChef__factory);

  await gwit.init(grp.address, farm_pool.address);
};

export default func;
func.tags = ["grp"];
