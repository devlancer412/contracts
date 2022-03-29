import { RoosterEgg__factory } from "../types";
import { Ship, Time } from "../utils";

const main = async () => {
  const { connect, accounts } = await Ship.init();
  const egg = await connect(RoosterEgg__factory);

  //Open egg sale
  const currentTime = await egg.getTime();
  const openingTime = currentTime + 30;
  const closingTime = currentTime + 100;
  const supply = 150_000;
  const cap = 10;
  const price = 0;
  const cashbackPerEgg = 0;
  const tx1 = await egg.setPresale(openingTime, closingTime, supply, cap, price, cashbackPerEgg);
  tx1.wait();

  //Buy 2 egg from egg contract
  await Time.delay(30000);
  const tx2 = await egg.connect(accounts.deployer).buyEggs(2);
  tx2.wait();

  //Mint 50eggs
  const tx3 = await egg.mintEggs(accounts.deployer.address, 50);
  tx3.wait();
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
