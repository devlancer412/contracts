import { DeployFunction } from "hardhat-deploy/types";
import { Gaff__factory, Gem__factory, Rooster__factory } from "../types";
import { GameItem__factory } from "../types/factories/GameItem__factory";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy } = await Ship.init(hre);

  let roosterBaseUri: string;
  let gaffUri: string;
  let gemUri: string;
  let gameItemUri: string;

  if (hre.network.tags.prod) {
    roosterBaseUri = "";
    gaffUri = "";
    gemUri = "";
    gameItemUri = "";
  } else {
    roosterBaseUri = "";
    gaffUri = "";
    gemUri = "";
    gameItemUri = "";
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
  await deploy(GameItem__factory, {
    args: [gameItemUri],
  });
};

export default func;
func.tags = ["nfts"];
