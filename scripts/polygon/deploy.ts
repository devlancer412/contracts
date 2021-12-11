import { RoosterEgg__factory, USDC__factory } from "../../typechain";
import { MacroChain, toWei, verifyContract } from "../../utils";

const main = async () => {
  const { deployer, owner } = await MacroChain.init();

  //Deploy RoosterEgg
  const usdcAddr = "0x2791bca1f2de4661ed88a30c99a7a9449aa84174";
  const vault = "0x2708D27F671B837123D17099C8871bE244D50a61";
  const initialTokenId = 1;
  const uri = "https://api.roosterwars.io/metadata/egg/";
  await deployer<RoosterEgg__factory>("RoosterEgg", [usdcAddr, vault, initialTokenId, uri], true);
};

main()
  .then(async () => await verifyContract("RoosterEgg"))
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
