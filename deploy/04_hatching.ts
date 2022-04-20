import { DeployFunction } from "hardhat-deploy/types";
import {
  Gaff__factory,
  Gem__factory,
  RoosterEggHatching__factory,
  RoosterEgg__factory,
  Rooster__factory,
} from "../types";
import { Ship, Time } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect, accounts } = await Ship.init(hre);

  const egg = await connect(
    RoosterEgg__factory,
    hre.network.tags.prod ? "0xbDD4AE46B65977a1d06b365c09B4e0F429c70Aef" : undefined,
  );
  const rooster = await connect(Rooster__factory);
  const gaff = await connect(Gaff__factory);
  const gem = await connect(Gem__factory);

  const hatching = await deploy(RoosterEggHatching__factory, {
    args: [accounts.signer.address, egg.address, rooster.address, gaff.address, gem.address],
  });

  await Time.delay(3000);

  if (hatching.newlyDeployed) {
    const tx1 = await rooster.grantRole("MINTER", hatching.address);
    await tx1.wait();
    const tx2 = await gaff.grantRole("MINTER", hatching.address);
    await tx2.wait();
    const tx3 = await gem.grantRole("MINTER", hatching.address);
    await tx3.wait();
  }
};

export default func;
func.tags = ["hatching"];
