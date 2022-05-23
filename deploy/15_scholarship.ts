import { deployments } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { Rooster__factory, Scholarship__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect } = await Ship.init(hre);
  await deployments.fixture(["grp", "gwit", "gwit_init", "nfts"]);

  const rooster = await connect(Rooster__factory);
  await deploy(Scholarship__factory, {
    args: [rooster.address],
  });
};

export default func;
func.tags = ["scholarship"];
