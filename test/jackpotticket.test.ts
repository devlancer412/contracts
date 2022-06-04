import { BigNumber } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { JackPotTicket, JackPotTicket__factory, GWITToken, GWITToken__factory } from "../types";
import { deployments, network } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { Ship } from "../utils";
import { arrayify, solidityKeccak256, splitSignature } from "ethers/lib/utils";

chai.use(solidity);
const { expect } = chai;

let ship: Ship;
let gwit: GWITToken;
let jackpotTicket: JackPotTicket;
let alice: SignerWithAddress;
let signer: SignerWithAddress;
let deployer: SignerWithAddress;
let users: SignerWithAddress[];

let hashedServerSeed: string;

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["jackpot_ticket", "mocks", "gwit", "grp", "gwit_init"]);

  return {
    ship,
    accounts,
    users,
  };
});

const signCreate = async (to: string, token: string, seed: string) => {
  const hash = solidityKeccak256(["address", "address", "string"], [to, token, seed]);
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
    deployer = scaffold.accounts.deployer;
    signer = scaffold.accounts.signer;
    users = scaffold.users;

    gwit = await scaffold.ship.connect(GWITToken__factory);
    jackpotTicket = await scaffold.ship.connect(JackPotTicket__factory);
    await jackpotTicket.grantRole("CREATOR", signer.address);
    await jackpotTicket.grantRole("MINTER", signer.address);
  });

  it("Distribute NFTs to users and charge token to jackpot", async () => {
    const distributePromise = users.map((user) => jackpotTicket.connect(signer).mintTo(1, user.address));
    await Promise.all(distributePromise);
    expect(await jackpotTicket.balanceOf(alice.address)).to.eq(1);

    await gwit.connect(deployer).transfer(jackpotTicket.address, 5000);
  });

  it("Create a round", async () => {
    const serverSeedString = "First round";
    const sig = await signCreate(signer.address, gwit.address, serverSeedString);
    await jackpotTicket.connect(signer).createRound("First round", gwit.address, sig);
  });

  it("Get client seed", async () => {
    hashedServerSeed = await jackpotTicket.getHashedServerSeed();
  });

  it("Can't get serverseed before finish", async () => {
    await expect(jackpotTicket.connect(alice).getServerSeed()).to.be.revertedWith(
      "JackPotTicket:NOT_FINISHED",
    );
  });

  it("Finished round and get result", async () => {
    // send time to over
    await network.provider.send("evm_increaseTime", [8 * 24 * 60 * 60]);
    await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp

    const resultPromises = users.map((user) => jackpotTicket.connect(user).getResult());
    const results = (await Promise.all(resultPromises)).map((result) => result.toNumber());

    const topWinnerResult = results.reduce((a, b) => (a > b ? a : b), 0);
    const topWinner = users[results.indexOf(topWinnerResult)];

    expect(topWinnerResult).to.eq(4000);
    expect(await gwit.balanceOf(topWinner.address)).to.eq(0);
    await jackpotTicket.connect(topWinner).withdrawReward();

    expect(await gwit.balanceOf(topWinner.address)).to.eq(4000);
  });

  it("Provably test", async () => {
    const serverSeed = await jackpotTicket.getServerSeed();
    const openTime = await jackpotTicket.getOpenTime();
    expect(solidityKeccak256(["bytes32", "uint256"], [serverSeed, openTime])).to.eq(hashedServerSeed);

    const clientSeed = await jackpotTicket.getClienctSeed();
    const aliceReward = await jackpotTicket.connect(alice).getResult();
    let addressList: Array<string> = [];
    addressList = (await jackpotTicket.getAddressList()).map((address) => address);

    const hashed = solidityKeccak256(
      ["bytes32", "bytes32", "uint256"],
      [serverSeed, clientSeed, addressList.length],
    );

    const winnerIndex = BigNumber.from(hashed).mod(addressList.length).toNumber();

    const { tokenName, amount } = await jackpotTicket.getTotalReward();

    let aliceRewardTest = 0;
    if (addressList[winnerIndex] == alice.address) {
      aliceRewardTest += (amount.toNumber() * 8) / 10;
    }

    for (let i = 1; i < 11; i++) {
      if (addressList[(winnerIndex + i) % addressList.length] == alice.address) {
        aliceRewardTest += (amount.toNumber() * 15) / 1000;
      }
    }

    expect(tokenName).to.eq("GWIT");
    expect(aliceReward).to.eq(aliceRewardTest);
  });
});
