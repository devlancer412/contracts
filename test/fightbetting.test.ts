import { BigNumber } from "ethers";
import {
  FightBetting__factory,
  GWITToken__factory,
  GWITToken,
  FightBetting,
  JackPotTicket,
  JackPotTicket__factory,
} from "../types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployments, ethers, network } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { Ship } from "../utils";
import { arrayify, formatEther, solidityKeccak256, splitSignature } from "ethers/lib/utils";
import { parseSpecial } from "../utils/parseSpecial";

chai.use(solidity);
const { expect } = chai;
const supply_size = parseSpecial("1bi|18");

let ship: Ship;
let fightbetting: FightBetting;
let gwit: GWITToken;
let jackpotTicket: JackPotTicket;
let alice: SignerWithAddress;
let bob: SignerWithAddress;
let vault: SignerWithAddress;
let signer: SignerWithAddress;
let deployer: SignerWithAddress;
let users: SignerWithAddress[];

const serverSeed = solidityKeccak256(["string"], ["FightBetting test"]);

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["fightbetting", "gwit", "jackpot_ticket"]);

  return {
    ship,
    accounts,
    users,
  };
});

const signCreate = async (
  to: string,
  fighter1: number,
  fighter2: number,
  startTime: number,
  endTime: number,
  minAmount: string,
  maxAmount: string,
  tokenAddr: string,
  hashedServerSeed: string,
) => {
  const hash = solidityKeccak256(
    ["address", "uint256", "uint256", "uint32", "uint32", "uint256", "uint256", "address", "bytes32"],
    [to, fighter1, fighter2, startTime, endTime, minAmount, maxAmount, tokenAddr, hashedServerSeed],
  );
  const sig = await signer.signMessage(arrayify(hash));
  const { r, s, v } = splitSignature(sig);
  return {
    r,
    s,
    v,
  };
};

const signFinish = async (to: string, bettingId: number, serverSeed: string, result: number) => {
  const hash = solidityKeccak256(
    ["address", "uint256", "bytes32", "bool"],
    [to, bettingId, serverSeed, result == 0],
  );
  const sig = await signer.signMessage(arrayify(hash));
  const { r, s, v } = splitSignature(sig);
  return {
    r,
    s,
    v,
  };
};

describe("FightBetting test", () => {
  before(async () => {
    const scaffold = await setup();

    alice = scaffold.accounts.alice;
    bob = scaffold.accounts.bob;
    vault = scaffold.accounts.vault;
    deployer = scaffold.accounts.deployer;
    signer = scaffold.accounts.signer;
    users = scaffold.users.slice(10, 20);

    fightbetting = await scaffold.ship.connect(FightBetting__factory);
    gwit = await scaffold.ship.connect(GWITToken__factory);
    jackpotTicket = await scaffold.ship.connect(JackPotTicket__factory);

    await fightbetting.setTokenAllowance(gwit.address, true);
    await fightbetting.grantRole("MAINTAINER", alice.address);
    expect(await fightbetting.hasRole("MAINTAINER", alice.address)).to.eq(true);
  });

  it("Initialize gwit token", async () => {
    const res = await gwit.initialSupply();
    expect(res).to.eq(supply_size);

    await gwit.connect(deployer).transfer(alice.address, 1000);
    expect(await gwit.balanceOf(alice.address)).to.eq(1000);
    await gwit.connect(deployer).transfer(bob.address, 1000);
    expect(await gwit.balanceOf(bob.address)).to.eq(1000);
    await gwit.connect(deployer).transfer(vault.address, 1000);
    expect(await gwit.balanceOf(vault.address)).to.eq(1000);

    await jackpotTicket.grantRole("MINTER", fightbetting.address);
    expect(await gwit.balanceOf(jackpotTicket.address)).to.eq(0);
    await fightbetting.connect(deployer).setJackPotMin(1);
  });

  it("Set signer", async () => {
    await fightbetting.grantRole("SIGNER", signer.address);
    expect(await fightbetting.hasRole("SIGNER", signer.address)).to.be.equal(true);
  });

  it("Alice creates a betting", async () => {
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;

    const startTime = timestampBefore + 100;
    const endTime = startTime + 3600;

    const minAmount = "100";
    const maxAmount = "5000";
    const hashedServerSeed = solidityKeccak256(["bool", "bytes32"], [true, serverSeed]);

    const sig = await signCreate(
      alice.address,
      0,
      1,
      startTime,
      endTime,
      minAmount,
      maxAmount,
      gwit.address,
      hashedServerSeed,
    );

    await fightbetting
      .connect(alice)
      .createBetting(0, 1, startTime, endTime, minAmount, maxAmount, gwit.address, hashedServerSeed, sig);

    await network.provider.send("evm_setNextBlockTimestamp", [startTime]);
    await network.provider.send("evm_mine");

    const result = await fightbetting.getBettingState(0);
    expect(result.bettorCount1.toNumber()).to.eq(0);
    expect(result.bettorCount2.toNumber()).to.eq(0);
    expect(parseFloat(formatEther(result.totalAmount1.toString()))).to.eq(0);
    expect(parseFloat(formatEther(result.totalAmount2.toString()))).to.eq(0);
  });

  it("Prepare for provably test : create & betting", async () => {
    const transferPromises = users.map((user) => gwit.connect(deployer).transfer(user.address, 1000));
    await Promise.all(transferPromises);
    // alice creates a new betting
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;

    const startTime = timestampBefore + 100;
    const endTime = startTime + 3600;
    const minAmount = "100";
    const maxAmount = "5000";
    const hashedServerSeed = solidityKeccak256(["bool", "bytes32"], [true, serverSeed]);

    const sigCreate = await signCreate(
      alice.address,
      0,
      1,
      startTime,
      endTime,
      minAmount,
      maxAmount,
      gwit.address,
      hashedServerSeed,
    );

    await fightbetting
      .connect(alice)
      .createBetting(
        0,
        1,
        startTime,
        endTime,
        minAmount,
        maxAmount,
        gwit.address,
        hashedServerSeed,
        sigCreate,
      );

    await network.provider.send("evm_setNextBlockTimestamp", [startTime]);
    await network.provider.send("evm_mine");

    // bets
    for (let index = 0; index < users.length; index++) {
      await gwit.connect(users[index]).approve(fightbetting.address, 500);
      await fightbetting.connect(users[index]).bettOne(1, index % 2, 500);
    }

    await expect(fightbetting.getServerSeed(1)).to.be.revertedWith("FightBetting:NOT_FINISHED");
  });

  it("Amount may be between min and max", async () => {
    await expect(fightbetting.connect(alice).bettOne(0, 1, 10)).to.be.revertedWith(
      "FightBetting:TOO_SMALL_AMOUNT",
    );

    await expect(fightbetting.connect(alice).bettOne(0, 1, 10000)).to.be.revertedWith(
      "FightBetting:TOO_MUCH_AMOUNT",
    );
  });

  it("Alice bets first fighter with 100 GWIT", async () => {
    await gwit.connect(alice).approve(fightbetting.address, 100);
    const tx1 = await fightbetting.connect(alice).bettOne(0, 0, 100);

    await tx1.wait();

    const bettingState = await fightbetting.getBettingState(0);
    expect(bettingState.bettorCount1.toNumber()).to.eq(1);
    expect(bettingState.totalAmount1.toNumber()).to.eq(100);
  });

  it("Bob bets first fighter with 200 GWIT", async () => {
    await gwit.connect(bob).approve(fightbetting.address, 200);
    const tx1 = await fightbetting.connect(bob).bettOne(0, 0, 200);

    await tx1.wait();

    const bettingState = await fightbetting.getBettingState(0);
    expect(bettingState.bettorCount1.toNumber()).to.eq(2);
    expect(bettingState.totalAmount1.toNumber()).to.eq(300);
  });

  it("Bob trys to transfer 1000 GWIT to alice", async () => {
    await expect(gwit.connect(bob).transfer(alice.address, 1000)).to.be.revertedWith(
      "ERC20: transfer amount exceeds balance",
    );
  });

  it("Vault bets second fighter with 300 GWIT", async () => {
    await gwit.connect(vault).approve(fightbetting.address, 300);
    const tx1 = await fightbetting.connect(vault).bettOne(0, 1, 300);

    await tx1.wait();

    const bettingState = await fightbetting.getBettingState(0);
    expect(bettingState.bettorCount2.toNumber()).to.eq(1);
    expect(bettingState.totalAmount2.toNumber()).to.eq(300);
  });

  it("Bob can't bet again", async () => {
    await gwit.connect(bob).approve(fightbetting.address, 200);
    await expect(fightbetting.connect(bob).bettOne(0, 0, 200)).to.be.revertedWith("FightBetting:ALREADY_BET");
  });

  it("Betting is finished", async () => {
    // send time to over
    await network.provider.send("evm_increaseTime", [3600]);
    await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp

    const sig = await signFinish(alice.address, 0, serverSeed, 0);
    await fightbetting.connect(alice).finishBetting(0, serverSeed, 0, sig);
  });

  it("Can't bet after finished", async () => {
    await expect(fightbetting.connect(deployer).bettOne(0, 1, 300)).to.be.revertedWith(
      "FightBetting:ALREADY_FINISHED",
    );
  });

  it("Alice and bob withdraws their token", async () => {
    const amountOfAlice = await gwit.balanceOf(alice.address);
    const amountOfBob = await gwit.balanceOf(bob.address);

    expect(await gwit.balanceOf(fightbetting.address)).to.be.eq(5570); // 5600 - 600/20

    const aliceIndex = await fightbetting.connect(alice).getBettorIndex(0);
    await fightbetting.connect(alice).withdrawReward(0, aliceIndex);
    const bobIndex = await fightbetting.connect(bob).getBettorIndex(0);
    await fightbetting.connect(bob).withdrawReward(0, bobIndex);

    expect(await gwit.balanceOf(alice.address)).to.be.eq(amountOfAlice.add(176)); // 600 * 88 / 100 / 3 = 176
    expect(await gwit.balanceOf(bob.address)).to.be.eq(amountOfBob.add(352)); // (600 * 88 / 100) * 2 / 3 = 352
    expect(await gwit.balanceOf(fightbetting.address)).to.be.eq(5042); // 600 * 12 / 100 = 72
  });

  it("Get lucky winner data", async () => {
    await fightbetting.connect(alice).withdrawLuckyWinnerReward(0);
    await fightbetting.connect(bob).withdrawLuckyWinnerReward(0);
    expect(await gwit.balanceOf(fightbetting.address)).to.be.eq(5030); // 5042 - 600/50(Lucky winner reward)
  });

  it("Prepare for provably test: finishing", async () => {
    // send time to over
    await network.provider.send("evm_increaseTime", [3601]);
    await network.provider.send("evm_mine");

    const sigFinish = await signFinish(alice.address, 1, serverSeed, 0);
    await fightbetting.connect(alice).finishBetting(1, serverSeed, 0, sigFinish);
  });

  it("Provably test : lucky winner", async () => {
    const serverSeed = await fightbetting.getServerSeed(1);
    const clientSeed = await fightbetting.getClientSeed(1);
    const stateResult = await fightbetting.getBettingState(1);
    const winnerIds = await fightbetting.getWinBettorIds(1);
    const winnerBettorCount = stateResult.side == 0 ? stateResult.bettorCount1 : stateResult.bettorCount2;
    const luckyWinnerRewardAmount = stateResult.totalAmount1.add(stateResult.totalAmount2).div(50);

    const hashed = solidityKeccak256(
      ["bytes32", "bytes32", "uint256", "uint256"],
      [serverSeed, clientSeed, winnerBettorCount, luckyWinnerRewardAmount],
    );

    const goldIndex = BigNumber.from(hashed).mod(winnerIds.length).toNumber();

    const silverIndex = (goldIndex + 1) % winnerIds.length;
    const bronzeIndex = (goldIndex + 2) % winnerIds.length;

    const luckyResult = await fightbetting.connect(users[2]).getLuckyWinner(1);
    // compare
    expect((await fightbetting.getBettorData(1, goldIndex)).bettor).to.eq(luckyResult.winners[0]);
    expect((await fightbetting.getBettorData(1, silverIndex)).bettor).to.eq(luckyResult.winners[1]);
    expect((await fightbetting.getBettorData(1, bronzeIndex)).bettor).to.eq(luckyResult.winners[2]);
  });

  it("JackPot balance test", async () => {
    expect(await gwit.balanceOf(jackpotTicket.address)).to.eq(280);
  });

  it("Minter can get JackPot NFT", async () => {
    const resultAmount = await fightbetting.connect(alice).jackPotNFTAmount();
    expect(resultAmount).to.eq(1);
    expect(await jackpotTicket.balanceOf(alice.address)).to.eq(0);

    await fightbetting.connect(alice).getJackPotNFT();
    expect(await jackpotTicket.balanceOf(alice.address)).to.eq(1);
  });
});
