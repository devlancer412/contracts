import { task } from "hardhat/config";

import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, "./.env") });

import { HardhatUserConfig, NetworkUserConfig } from "hardhat/types";
import "hardhat-deploy";
import "hardhat-deploy-ethers";

import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";

import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-etherscan";

const chainIds = {
  mainnet: 1,
  rinkeby: 4,
  hardhat: 31337,
  polygon: 137,
  mumbai: 80001,
};

const MNEMONIC_LOCALHOST = process.env.MNEMONIC_LOCALHOST || "";
const MNEMONIC_TESTNET = process.env.MNEMONIC_TESTNET || "";
const MNEMONIC_MAINNET = process.env.MNEMONIC_MAINNET || "";
const MORALIS_API_KEY = process.env.MORALIS_API_KEY || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const POLYSCAN_API_KEY = process.env.POLYSCAN_API_KEY || "";
const REPORT_GAS = process.env.REPORT_GAS || "";

let blockchain: "eth" | "polygon" = "eth";

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

function createNetworkConfig(network: keyof typeof chainIds): NetworkUserConfig {
  let mnemonic = "";
  let url = "https://speedy-nodes-nyc.moralis.io/" + MORALIS_API_KEY;

  switch (network) {
    case "mainnet":
    case "rinkeby":
      url = url + "/eth/" + network;
      blockchain = "eth";
      break;
    case "polygon":
    case "mumbai":
      url = url + "/polygon/" + network;
      blockchain = "polygon";
      break;
  }

  switch (network) {
    case "mainnet":
    case "polygon":
      mnemonic = MNEMONIC_MAINNET;
      break;
    case "rinkeby":
    case "mumbai":
      mnemonic = MNEMONIC_TESTNET;
      break;
  }

  url = "https://polygon-mainnet.g.alchemy.com/v2/2hy-4P86bHQbdnKMtyPgG5FBeatJuXMN";

  return {
    accounts: {
      count: 10,
      initialIndex: 0,
      mnemonic,
      path: "m/44'/60'/0'/0",
    },
    chainId: chainIds[network],
    url,
  };
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic: MNEMONIC_LOCALHOST,
      },
      chainId: 137,
      mining: {
        auto: true,
        interval: 1000
      }
    },
    mainnet: createNetworkConfig("mainnet"),
    rinkeby: createNetworkConfig("rinkeby"),
    polygon: createNetworkConfig("polygon"),
    mumbai: createNetworkConfig("mumbai"),
  },
  etherscan: {
    apiKey: blockchain === "eth" ? ETHERSCAN_API_KEY : POLYSCAN_API_KEY
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 100,
    enabled: REPORT_GAS === "true"
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
  mocha: {
    timeout: 20000000,
  },
};

export default config;
