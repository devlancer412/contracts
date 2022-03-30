import { DeployFunction } from "hardhat-deploy/types";
import { Gaff__factory, Gem__factory, Rooster__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy } = await Ship.init(hre);

  let roosterBaseUri: string;
  let gaffUri: string;
  let gemUri: string;

  if (hre.network.tags.prod) {
    roosterBaseUri = "";
    gaffUri = "";
    gemUri = "";
  } else {
    roosterBaseUri = "";
    gaffUri = "";
    gemUri = "";
  }

  await deploy(Rooster__factory, {
    args: [roosterBaseUri],
  });
  await deploy(Gaff__factory, {
    args: [gaffUri],
  });
  await deploy(Gem__factory, {
    args: [gemUri],
  });
};

export default func;
func.tags = ["nfts"];
