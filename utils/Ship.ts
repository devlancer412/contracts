import hardhatRuntimeEnvironment, { ethers } from "hardhat";
import { ContractFactory } from "ethers";
import { SignerWithAddress } from "hardhat-deploy-ethers/signers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployOptions } from "hardhat-deploy/types";

type DeployParam<T extends ContractFactory> = Parameters<InstanceType<{ new (): T }>["deploy"]>;
type ContractInstance<T extends ContractFactory> = ReturnType<InstanceType<{ new (): T }>["attach"]>;
type Modify<T, R> = Omit<T, keyof R> & R;

export interface Users {
  [name: string]: SignerWithAddress;
}

class Ship {
  public users: Users;
  private hre: HardhatRuntimeEnvironment;
  private log: boolean | undefined;

  constructor(hre: HardhatRuntimeEnvironment, users: Users, log?: boolean) {
    this.hre = hre;
    this.log = log;
    this.users = users;
  }

  static init = async (
    hre: HardhatRuntimeEnvironment = hardhatRuntimeEnvironment,
    log?: boolean,
  ): Promise<Ship> => {
    const namedAccounts = await hre.getNamedAccounts();
    const users: Users = {};
    for (const [name, address] of Object.entries(namedAccounts)) {
      const signer = await ethers.getSigner(address);
      users[name] = signer;
    }
    const ship = new Ship(hre, users, log);
    return ship;
  };

  strangers = async (): Promise<SignerWithAddress[]> => {
    const strangers: SignerWithAddress[] = [];
    const unnammedAccounts = await this.hre.getUnnamedAccounts();
    for (const [index, address] of unnammedAccounts.entries()) {
      const signer = await ethers.getSigner(address);
      strangers[index] = signer;
    }
    return strangers;
  };

  singers = (): SignerWithAddress[] => {
    const signers: SignerWithAddress[] = [];
    for (const [, user] of Object.entries(this.users)) {
      signers.push(user);
    }
    return signers;
  };

  addresses = (): string[] => {
    const addresses: string[] = [];
    for (const [, user] of Object.entries(this.users)) {
      addresses.push(user.address);
    }
    return addresses;
  };

  deploy = async <T extends ContractFactory>(
    contractFactory: new () => T,
    option?: Modify<
      DeployOptions,
      {
        from?: SignerWithAddress;
        args?: DeployParam<T>;
        log?: boolean;
      }
    >,
  ): Promise<ContractInstance<T>> => {
    const contractName = contractFactory.name.split("__")[0];
    const from = option?.from?.address || this.users.deployer.address;

    let log = option?.log || this.log;
    if (log === undefined) {
      if (this.hre.network.name !== "hardhat") {
        log = true;
      } else {
        log = false;
      }
    }
    const { address } = await this.hre.deployments.deploy(contractName, {
      ...option,
      from,
      args: option?.args,
      log,
    });

    const contract = (await ethers.getContractAt(contractName, address, from)) as ContractInstance<T>;

    return contract;
  };

  connect = async <T extends ContractFactory>(
    contractFactory: new () => T,
    newAddress?: string,
  ): Promise<ContractInstance<T>> => {
    const contractName = contractFactory.name.split("__")[0];
    if (newAddress) {
      const factory = (await ethers.getContractFactory(contractName, this.users.deployer)) as T;
      return factory.attach(newAddress) as ContractInstance<T>;
    } else {
      return (await ethers.getContract(contractName, this.users.deployer)) as ContractInstance<T>;
    }
  };
}

export default Ship;
