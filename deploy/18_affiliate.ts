import { Affiliate__factory, MockUsdc__factory, RoosterEggSale__factory } from "../types";
import { DeployFunction } from "hardhat-deploy/types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect, accounts } = await Ship.init(hre);

  const usdc = await connect(MockUsdc__factory);
  const eggSale = await connect(RoosterEggSale__factory);

  await deploy(Affiliate__factory, {
    args: [usdc.address, accounts.signer.address],
  });
  const affiliate = await connect(Affiliate__factory);

  await affiliate.setEggSaleData(eggSale.address, 50);
  await eggSale.setAffiliateContract(affiliate.address);
};

export default func;
func.tags = ["affiliate"];
func.dependencies = ["mocks", "eggsale"];
