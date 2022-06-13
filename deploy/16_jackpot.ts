import { BigNumber, BigNumberish } from "ethers";
import { JackPotTicket__factory, MockVRFCoordinatorV2__factory } from "../types";
import { deployments } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { Ship } from "../utils";

const func: DeployFunction = async (hre) => {
  const { deploy, connect } = await Ship.init(hre);

  let coordiatorAddress;
  let subscriptionId;

  if (hre.network.tags.prod) {
    coordiatorAddress = "0x0000000"; // polygon mainnet coordiator address
  } else if (hre.network.tags.test) {
    coordiatorAddress = "0x6168499c0cFfCaCD319c818142124B7A15E857ab"; // rinkeby test net coordiator address
  } else {
    const coordiator = await connect(MockVRFCoordinatorV2__factory);
    coordiatorAddress = coordiator.address;
    const tx = await coordiator.createSubscription();
    const block = await tx.wait();

    subscriptionId = !!block.events && block.events[0]?.args?.subId;
  }

  await deploy(JackPotTicket__factory, {
    args: [BigNumber.from(subscriptionId), coordiatorAddress],
  });
};

export default func;
func.tags = ["jackpot_ticket"];
func.dependencies = ["mocks"];
