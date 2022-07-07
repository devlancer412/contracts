import { DeployFunction } from "hardhat-deploy/types";
import { MockUsdc__factory, MockVRFCoordinatorV2__factory } from "../types";
import { toWei, Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, users, accounts } = await Ship.init(hre);
  const usdc = await deploy(MockUsdc__factory);
  let nonce = await hre.ethers.provider.getTransactionCount(accounts.deployer.address);
  if (usdc.newlyDeployed) {
    for (let i = 1; i < 5; i++) {
      const tx = await usdc.contract.transfer(users[i].address, toWei(1000, 6), { nonce: nonce++ });
      await tx.wait();
    }
  }

  await deploy(MockVRFCoordinatorV2__factory, {
    args: [0, 0],
  });
};

export default func;
func.tags = ["mocks"];
