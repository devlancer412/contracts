import { deployments } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { GWITToken__factory, Store__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect, users, accounts } = await Ship.init(hre);

  const gwit = await connect(GWITToken__factory);
  await deploy(Store__factory, {
    args: [gwit.address, users[0].address],
  });
};

export default func;
func.tags = ["store"];
func.dependencies = ["mocks", "grp", "gwit", "gwit_init", "nfts"];
