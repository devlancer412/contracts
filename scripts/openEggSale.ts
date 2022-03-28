import { RoosterEggSale__factory, RoosterEgg__factory } from "../types";
import { Ship, Time, toWei } from "../utils";

const main = async () => {
  const { connect, provider, accounts } = await Ship.init();
  const egg = await connect(RoosterEgg__factory);
  const eggsale = await connect(RoosterEggSale__factory);

  await egg.transferOwnership(eggsale.address);

  const currentTime = (await provider.getBlock(await provider.getBlockNumber())).timestamp;
  const openingTime = currentTime + Time.fromMin(10).toSec();
  const closingTime = openingTime + Time.fromDay(2).toSec();
  const supply = 150000;
  const cap = 10;
  const whitelist = false;
  const price = toWei(30, 6);
  const cashback = toWei(0.045, 18);
  await eggsale.setEggSale(openingTime, closingTime, supply, cap, whitelist, price, cashback);

  await accounts.deployer.sendTransaction({
    to: eggsale.address,
    value: toWei(100, 18),
  });
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
