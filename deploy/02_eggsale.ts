import { DeployFunction } from "hardhat-deploy/types";
import { RoosterEgg__factory, MockUsdc__factory, RoosterEggSale__factory, Egg__factory } from "../types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect, accounts } = await Ship.init(hre);

  if (hre.network.tags.prod) {
    const usdcAddr = "0x2791bca1f2de4661ed88a30c99a7a9449aa84174";
    const walletAddr = "0x2708D27F671B837123D17099C8871bE244D50a61";
    const eggAddr = "0xbDD4AE46B65977a1d06b365c09B4e0F429c70Aef";
    const signerAddr = "0xC785994bB51ED41d801bB491B0CDa7CA1cEa3C56";
    const minted = 7172;
    await deploy(RoosterEggSale__factory, {
      args: [usdcAddr, eggAddr, walletAddr, signerAddr, minted],
    });
  } else {
    const usdc = await connect(MockUsdc__factory);
    const wallet = accounts.vault.address;
    const egg = await connect(RoosterEgg__factory);
    const signer = accounts.signer.address;
    const minted = 52;
    await deploy(RoosterEggSale__factory, {
      args: [usdc.address, egg.address, wallet, signer, minted],
    });
  }
};

export default func;
func.tags = ["eggsale"];
