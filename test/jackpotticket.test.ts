import { BigNumber } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  JackPotTicket,
  JackPotTicket__factory,
  MockUsdc,
  MockUsdc__factory,
  MockVRFCoordinatorV2,
  MockVRFCoordinatorV2__factory,
} from "../types";
import { deployments, network } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { Ship } from "../utils";
import { arrayify, solidityKeccak256, splitSignature } from "ethers/lib/utils";

chai.use(solidity);
const { expect } = chai;

let ship: Ship;
let usdc: MockUsdc;
let jackpotTicket: JackPotTicket;
let coordinator: MockVRFCoordinatorV2;
let alice: SignerWithAddress;
let bob: SignerWithAddress;
let signer: SignerWithAddress;
let deployer: SignerWithAddress;
let users: SignerWithAddress[];

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["jackpot_ticket", "mocks"]);

  return {
    ship,
    accounts,
    users,
  };
});

const signCreate = async (to: string, token: string) => {
  const hash = solidityKeccak256(["address", "address"], [to, token]);
  const sig = await signer.signMessage(arrayify(hash));
  const { r, s, v } = splitSignature(sig);
  return {
    r,
    s,
    v,
  };
};

const signFinish = async (to: string) => {
  const hash = solidityKeccak256(["address"], [to]);
  const sig = await signer.signMessage(arrayify(hash));
  const { r, s, v } = splitSignature(sig);
  return {
    r,
    s,
    v,
  };
};

describe("JackPot test", () => {
  before(async () => {
    const scaffold = await setup();

    alice = scaffold.accounts.alice;
    bob = scaffold.accounts.bob;
    deployer = scaffold.accounts.deployer;
    signer = scaffold.accounts.signer;
    users = scaffold.users;

    usdc = await scaffold.ship.connect(MockUsdc__factory);
    jackpotTicket = await scaffold.ship.connect(JackPotTicket__factory);
    coordinator = await scaffold.ship.connect(MockVRFCoordinatorV2__factory);

    await jackpotTicket.grantRole("SIGNER", signer.address);
    await jackpotTicket.grantRole("MINTER", signer.address);
    await jackpotTicket.grantRole("MAINTAINER", signer.address);

    await jackpotTicket.setTokenAllowance(usdc.address, true);
  });

  it("Distribute NFTs to users and charge token to jackpot", async () => {
    const distributePromise = users.map((user) => jackpotTicket.connect(signer).mintTo(1, user.address));
    await Promise.all(distributePromise);
    expect(await jackpotTicket.balanceOf(alice.address)).to.eq(1);

    await usdc.connect(deployer).transfer(jackpotTicket.address, 5000);
  });

  it("Create a round", async () => {
    const sig = await signCreate(signer.address, usdc.address);
    await jackpotTicket.connect(signer).createRound(usdc.address, sig);
  });

  it("Can't get server seed before finish", async () => {
    await expect(jackpotTicket.connect(alice).getServerSeed()).to.be.revertedWith(
      "JackPotTicket:NOT_FINISHED",
    );
  });

  it("Finished round", async () => {
    // send time to over
    await network.provider.send("evm_increaseTime", [8 * 24 * 60 * 60]);
    await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp

    const sig = await signFinish(signer.address);
    const tx = await jackpotTicket.connect(signer).finishRound(sig);
    const result = await tx.wait();

    const requestId = result.events?.filter((event) => event.event == "NewRequest")[0]?.args?.id;
    const tx1 = await coordinator.fulfillRandomWords(requestId, jackpotTicket.address);
    await tx1.wait();
  });

  it("Get result", async () => {
    const resultPromises = users.map((user) => jackpotTicket.connect(user).getResult());
    const results = (await Promise.all(resultPromises)).map((result) => result.toNumber());

    const topWinnerResult = results.reduce((a, b) => (a > b ? a : b), 0);
    const topWinner = users[results.indexOf(topWinnerResult)];

    expect(topWinnerResult).to.eq(4000);
    const balance = await usdc.balanceOf(topWinner.address);
    await jackpotTicket.connect(topWinner).withdrawReward();
    expect(await usdc.balanceOf(topWinner.address)).to.eq(balance.add(4000));
  });

  it("Provably test", async () => {
    const serverSeed = await jackpotTicket.getServerSeed();
    const clientSeed = await jackpotTicket.clientSeed();
    const aliceReward = await jackpotTicket.connect(alice).getResult();
    let addressList: Array<string> = [];
    addressList = (await jackpotTicket.getAddressList()).map((address) => address);

    let hashed = solidityKeccak256(
      ["bytes32", "bytes32", "uint256"],
      [serverSeed, clientSeed, addressList.length],
    );

    hashed = solidityKeccak256(
      ["bytes32", "bytes32", "bytes32", "uint256"],
      [hashed, serverSeed, clientSeed, addressList.length],
    );
    let winnerIndex = BigNumber.from(hashed).mod(addressList.length).toNumber();

    const { tokenName, amount } = await jackpotTicket.getTotalReward();

    let aliceRewardTest = 0;
    if (addressList[winnerIndex] == alice.address) {
      aliceRewardTest += (amount.toNumber() * 8) / 10;
    }

    for (let i = 1; i < 11; i++) {
      hashed = solidityKeccak256(
        ["bytes32", "bytes32", "bytes32", "uint256"],
        [hashed, serverSeed, clientSeed, addressList.length],
      );
      winnerIndex = BigNumber.from(hashed).mod(addressList.length).toNumber();

      if (addressList[winnerIndex % addressList.length] == alice.address) {
        aliceRewardTest += (amount.toNumber() * 15) / 1000;
      }
    }

    expect(tokenName).to.eq("USDC");
    expect(aliceReward).to.eq(aliceRewardTest);
  });

  // it("Alice withdraw money", async () => {
  //   const initailAmount = await usdc.balanceOf(alice.address);
  //   const rewardAmount = await jackpotTicket.connect(alice).getResult();
  //   await jackpotTicket.connect(alice).withdrawReward();
  //   expect(await usdc.balanceOf(alice.address)).to.eq(initailAmount.add(rewardAmount));
  // });

  it("Bob can't withdraw after new time overed", async () => {
    // send time to over
    await network.provider.send("evm_increaseTime", [3 * 24 * 60 * 60]);
    await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp

    await expect(jackpotTicket.connect(bob).withdrawReward()).to.be.revertedWith("JackPotTicket:TIME_OVER");
  });
});
