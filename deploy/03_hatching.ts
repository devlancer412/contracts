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

  const p1 = rooster.grantMinterRole(hatching.address);
  const p2 = gaff.grantMinterRole(hatching.address);
  const p3 = gem.grantMinterRole(hatching.address);
  await Promise.all([p1, p2, p3]);
};

export default func;
func.tags = ["hatching"];
