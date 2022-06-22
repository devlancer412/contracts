import { BigNumber, Contract } from "ethers";
import { deployments } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { TrackableProxy, TrackableProxy__factory, MockUsdc, MockUsdc__factory } from "../types";
import { Ship } from "../utils";
import { hexlify, Interface, solidityPack } from "ethers/lib/utils";

chai.use(solidity);
const { expect } = chai;

let ship: Ship;
let proxy: TrackableProxy;
let proxyContract: Contract;
let usdc: MockUsdc;
let alice: SignerWithAddress;
let bob: SignerWithAddress;

const realAbi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "mint",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];
const abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "implementTo",
        type: "address",
      },
      {
        internalType: "address",
        name: "affiliate",
        type: "address",
      },
      {
        internalType: "uint32",
        name: "selector",
        type: "uint32",
      },
    ],
    name: "mint",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["mocks", "trackableproxy"]);

  return {
    accounts,
    users,
  };
});

describe("TrackableProxy test", () => {
  before(async () => {
    const scaffold = await setup();
    alice = scaffold.accounts.alice;
    bob = scaffold.accounts.bob;

    proxy = await ship.connect(TrackableProxy__factory);
    usdc = await ship.connect(MockUsdc__factory);
    proxyContract = new Contract(proxy.address, abi, ship.provider);
  });

  it("Mint usdc to alice and bob is affiliate", async () => {
    expect(proxy.address).to.eq(proxyContract.address);
    const beforeAmount = await usdc.balanceOf(alice.address);

    const ifaceReal = new Interface(realAbi);
    const selector = ifaceReal.getSighash("mint");

    // await usdc.mint(alice.address, 1000);
    const tx = await proxyContract.connect(alice).mint(
      alice.address, // mint to address of usdc mint function
      1000, // amount of usdc mint function
      usdc.address, // implement contract address
      bob.address, // affiliate address
      selector, // function selector
    );

    await tx.wait();

    const proxyEvent = await proxyContract.provider.getLogs({ address: proxy.address });

    expect(proxyEvent.length).to.eq(2);
    expect(BigNumber.from(proxyEvent[0].topics[2])).to.eq(BigNumber.from(alice.address.toString()));
    expect(BigNumber.from(proxyEvent[0].data)).to.eq(1000);
    expect(BigNumber.from(proxyEvent[1].topics[1])).to.eq(BigNumber.from(usdc.address));
    expect(BigNumber.from(proxyEvent[1].topics[0])).to.eq(BigNumber.from(bob.address));

    console.log("mint event", proxyEvent[0]);
    console.log("track event", proxyEvent[1]);
    const currentAmount = await usdc.balanceOf(alice.address);
    expect(currentAmount.sub(beforeAmount)).to.greaterThan(0);
  });
});
