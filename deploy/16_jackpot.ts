import { JackPotTicket__factory } from "../types";
import { deployments } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect } = await Ship.init(hre);

  await deploy(JackPotTicket__factory, {
    args: [],
  });
};

export default func;
func.tags = ["jackpot_ticket"];
