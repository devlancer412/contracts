import { DeployFunction } from "hardhat-deploy/types";
import { SeedGwit__factory } from "../types";
import { Ship, Time } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, accounts } = await Ship.init(hre);
  const { contract: aGwit } = await deploy(SeedGwit__factory);

  await Time.delay(3000);

  await aGwit.grantRole("MINTER", accounts.deployer.address);
};

export default func;
func.tags = ["sGWIT"];
