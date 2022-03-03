import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("upload", "Verfies deployed contract")
  .addParam("contract", "The name of the contract")
  .setAction(async (taskArgs, hre) => {
    const contractName = taskArgs.contract;
    const contract = await getContractSource(hre, contractName);
    const networkName = hre.network.name;
    const artifacts = require(`../deployments/${networkName}/${contractName}.json`);
    //eslint-disable-next-line @typescript-eslint/no-explicit-any
    const constructorArguments = (artifacts.args as any[]) || [];
    const address = artifacts.address as string;

    await hre.run("verify:verify", {
      address,
      constructorArguments,
      contract,
    });
  });

const getContractSource = async (
  hre: HardhatRuntimeEnvironment,
  contractName: string,
): Promise<string | undefined> => {
  const sourceNames = await hre.artifacts.getAllFullyQualifiedNames();

  for (let i = 0; i < sourceNames.length; i++) {
    const parts = sourceNames[i].split(":");
    if (parts[1] === contractName) {
      return sourceNames[i];
    }
  }
  return undefined;
};
