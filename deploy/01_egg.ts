import { DeployFunction } from "hardhat-deploy/types";
import { RoosterEgg__factory, MockUsdc__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect, accounts } = await Ship.init(hre);

  const initialTokenId = 1;
  if (!hre.network.tags.prod) {
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
