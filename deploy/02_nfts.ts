import { DeployFunction } from "hardhat-deploy/types";
import { Gaff__factory, Gem__factory, Rooster__factory } from "../types";
import { GameItem__factory } from "../types/factories/GameItem__factory";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy } = await Ship.init(hre);

  //eslint-disable-next-line @typescript-eslint/no-explicit-any
  const p: Promise<any>[] = [];

  if (hre.network.tags.prod) {
    p.push(
      deploy(Rooster__factory, {
        args: [""],
      }),
    );
    p.push(
      deploy(Gaff__factory, {
        args: [""],
      }),
    );
    p.push(
      deploy(Gem__factory, {
        args: [""],
      }),
    );
    p.push(
      deploy(GameItem__factory, {
        args: [""],
      }),
    );
  } else {
    p.push(
      deploy(Rooster__factory, {
        args: [""],
      }),
    );
    p.push(
      deploy(Gaff__factory, {
        args: [""],
      }),
    );
    p.push(
      deploy(Gem__factory, {
        args: [""],
      }),
    );
    p.push(
      deploy(GameItem__factory, {
        args: [""],
      }),
    );
  }

  await Promise.all(p);
};

export default func;
func.tags = ["nfts"];
