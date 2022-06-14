import { DeployFunction } from "hardhat-deploy/types";
import { MockUsdc__factory, Rooster__factory, Scholarship__factory, Tournament__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect, accounts } = await Ship.init(hre);

  const rooster = await connect(Rooster__factory);
  const scholarship = await connect(Scholarship__factory);
  const usdc = await connect(MockUsdc__factory);
  const valut = accounts.vault;

  const tournament = await deploy(Tournament__factory, {
    args: [usdc.address, rooster.address, scholarship.address, valut.address],
  });
};

export default func;
func.tags = ["tournament"];
func.dependencies = ["mocks", "nfts", "scholarship"];
