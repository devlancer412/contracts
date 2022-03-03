## Version

**2.0.0-alpha.1**

## Setting up local development

### Pre-requisites

- [Node.js](https://nodejs.org/en/) version 14.0+ and [yarn](https://yarnpkg.com/) for Javascript environment.
- [dapp.tools](https://github.com/dapphub/dapptools#installation) with [Nix](https://nixos.org/download.html) for running dapp tests.
  For Apple Silicon macs, install Nix v2.3.16-x86_64 (see [this issue](https://github.com/dapphub/dapptools/issues/878)).

1. Clone this repository

```bash
git clone https://github.com/Metadhana-Studio/roosterwars-contracts
```

2. Install dependencies

```bash
yarn
```

3. Set environment variables on the .env file according to .env.example

```bash
cp .env.example .env
vim .env
```

4. Compile Solidity programs

```bash
yarn compile
```

### Development

- To run hardhat tests

```bash
yarn test:hh
```

- To run dapp tests

```bash
yarn test:dapp
```

- To start local blockchain

```bash
yarn localnode
```

- To run scripts on Rinkeby test

```bash
yarn script:rinkeby ./scripts/....
```

- To run deploy contracts on Rinkeby testnet (uses Hardhat deploy)

```bash
yarn deploy:rinkeby --tags ....
```

... see more useful commands in package.json file

## Main Dependencies

Contracts are developed using well-known open-source software for utility libraries and developement tools. You can read more about each of them.

[OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts)

[Solmate](https://github.com/Rari-Capital/solmate)

[Hardhat](https://github.com/nomiclabs/hardhat)

[hardhat-deploy](https://github.com/wighawag/hardhat-deploy)

[dapp.tools](https://github.com/dapphub/dapptools)

[ethers.js](https://github.com/ethers-io/ethers.js/)

[TypeChain](https://github.com/dethcrypto/TypeChain)
