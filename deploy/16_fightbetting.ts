import { deployments } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { FightBetting__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect } = await Ship.init(hre);

  await deploy(FightBetting__factory, {
    args: [],
  });
};

export default func;
func.tags = ["fightbetting"];
