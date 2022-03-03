import { DeployFunction } from "hardhat-deploy/types";
import { RoosterEgg__factory, MockUsdc__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect, accounts } = await Ship.init(hre);

  const initialTokenId = 1;
  if (hre.network.tags.prod) {
    const usdcAddr = "0x2791bca1f2de4661ed88a30c99a7a9449aa84174";
    const walletAddr = "0x2708D27F671B837123D17099C8871bE244D50a61";
    const baseUri = "https://api.roosterwars.io/metadata/egg/";
    await deploy(RoosterEgg__factory, {
      args: [usdcAddr, walletAddr, initialTokenId, baseUri],
    });
  } else {
    const usdc = await connect(MockUsdc__factory);
    const wallet = accounts.vault.address;
    const baseUri = "https://mds-roosterwars-backend-test.azurewebsites.net/egg/metadata/";
    await deploy(RoosterEgg__factory, {
      args: [usdc.address, wallet, initialTokenId, baseUri],
    });
  }
};

export default func;
func.tags = ["egg"];
