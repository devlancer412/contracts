import { Interface } from "ethers/lib/utils";
import { Contract } from "ethers";
import {
  MockUsdc__factory,
  RoosterEggSale__factory,
  RoosterEgg__factory,
  Affiliate__factory,
} from "../types";
import { Ship, Time, toWei } from "../utils";
import { abiEgg, abiStore, realAbiEgg, realAbiStore } from "../test/AffiliateAbis.json";

const main = async () => {
  const { connect, provider, accounts } = await Ship.init();

  const usdc = await connect(MockUsdc__factory);
  const egg = await connect(RoosterEgg__factory);
  const eggsale = await connect(RoosterEggSale__factory);
  const affiliate = await connect(Affiliate__factory);
  await eggsale.setAffiliateData(affiliate.address, 50);

  const proxyContract = new Contract(affiliate.address, abiEgg, provider);
  const iRealFace = new Interface(realAbiEgg);

  console.log(await provider.getBalance(accounts.alice.address));

  await usdc.connect(accounts.alice).approve(eggsale.address, 500);
  const tx = await proxyContract.connect(accounts.alice).buyEggWithAffiliate(
    accounts.alice.address, // to address to send egg
    10, // amount of egg
    eggsale.address, // eggsale contract address
    accounts.bob.address, // affiliate address
    iRealFace.getSighash("buyEggWithAffiliate"), // function selector to replace
  );

  await tx.wait();
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
