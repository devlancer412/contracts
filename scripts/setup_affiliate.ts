import { Interface, solidityKeccak256 } from "ethers/lib/utils";
import { Contract } from "ethers";
import { RoosterEggSale__factory, RoosterEgg__factory, Store__factory, Affiliate__factory } from "../types";
import { Ship, Time, toWei } from "../utils";
import { abiEgg, abiStore, realAbiEgg, realAbiStore } from "../test/AffiliateAbis.json";

const main = async () => {
  const { connect, provider, accounts } = await Ship.init();

  console.log("preparing....");
  const egg = await connect(RoosterEgg__factory);
  const eggsale = await connect(RoosterEggSale__factory);
  const store = await connect(Store__factory);
  const affiliate = await connect(Affiliate__factory);

  console.log("setting egg sale");
  await eggsale.setAffiliateData(affiliate.address, 50);

  console.log("setting store");
  await store.setAffiliateAddress(affiliate.address);
  console.log("setting finished");
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
