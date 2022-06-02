import { deployments } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { FightBetting__factory, JackPotTicket__factory, JackPotTicket } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect } = await Ship.init(hre);
  await deployments.fixture(["mocks", "grp", "gwit", "gwit_init", "jackpot_ticket"]);

  const jackpotTicket: JackPotTicket = await connect(JackPotTicket__factory);
  await deploy(FightBetting__factory, {
    args: [jackpotTicket.address],
  });
};

export default func;
func.tags = ["fightbetting"];
