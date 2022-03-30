import { RoosterEggSale__factory } from "../types";
import { setTime, Ship, Time } from "../utils";

const main = async () => {
  const { connect } = await Ship.init();
  const eggsale = await connect(RoosterEggSale__factory);

  const { openingTime, closingTime } = await eggsale.eggsale();
  await setTime(closingTime);
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
