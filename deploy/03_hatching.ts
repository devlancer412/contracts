import { DeployFunction } from "hardhat-deploy/types";
import {
  Gaff__factory,
  Gem__factory,
  RoosterEggHatching__factory,
  RoosterEgg__factory,
  Rooster__factory,
} from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect, accounts } = await Ship.init(hre);

  const egg = await connect(RoosterEgg__factory);
  const rooster = await connect(Rooster__factory);
  const gaff = await connect(Gaff__factory);
  const gem = await connect(Gem__factory);

  const hatching = await deploy(RoosterEggHatching__factory, {
    args: [accounts.signer.address, egg.address, rooster.address, gaff.address, gem.address],
  });

  if (hatching.newlyDeployed) {
    const tx1 = await rooster.grantMinterRole(hatching.address);
    await tx1.wait();
    const tx2 = await gaff.grantMinterRole(hatching.address);
    await tx2.wait();
    const tx3 = await gem.grantMinterRole(hatching.address);
    await tx3.wait();
  }
};

export default func;
func.tags = ["hatching"];
