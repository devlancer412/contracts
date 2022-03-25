import { ethers } from "hardhat";
import { RoosterEgg__factory } from "../types";
import { Ship } from "../utils";

const main = async () => {
  const { connect, provider } = await Ship.init();
  const egg = await connect(RoosterEgg__factory);
  const currentTime = (await provider.getBlock(await provider.getBlockNumber())).timestamp;
  const openingTime = currentTime + 10;
  const closingTime = 4194967296;
  await egg.setPresale(openingTime, closingTime, 100000, 100, 0, 0);
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
