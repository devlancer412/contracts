import { FightBetting__factory } from "./../types/factories/contracts/betting/FightBetting__factory";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { FightBetting } from "./../types/contracts/betting/FightBetting";
import { deployments, ethers, network } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { Ship } from "../utils";
import { arrayify, formatEther, parseEther, solidityKeccak256, splitSignature } from "ethers/lib/utils";
import { Accounts } from "../utils/Ship";

chai.use(solidity);
const { expect } = chai;

let ship: Ship;
let fightbetting: FightBetting;
let alice: SignerWithAddress;
let bob: SignerWithAddress;
let vault: SignerWithAddress;
let accounts: Accounts;

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["fightbetting"]);

  return {
    ship,
    accounts,
    users,
  };
});

const sign = async (
  to: string,
  fighter1: number,
  fighter2: number,
  startTime: number,
  endTime: number,
  minAmount: string,
  maxAmount: string,
) => {
  const hash = solidityKeccak256(
    ["address", "uint256", "uint256", "uint32", "uint32", "uint256", "uint256"],
    [to, fighter1, fighter2, startTime, endTime, minAmount, maxAmount],
  );
  const sig = await accounts.signer.signMessage(arrayify(hash));
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

    accounts = scaffold.accounts;

    fightbetting = await scaffold.ship.connect(FightBetting__factory);
  });

  it("Set alice to signer", async () => {
    await fightbetting.grantRole("SIGNER", accounts.signer.address);
    expect(await fightbetting.hasRole("SIGNER", accounts.signer.address)).to.be.equal(true);
  });

  it("Alice creates a betting", async () => {
    const dt = new Date();
    const startTime = Math.floor(dt.getTime() / 1000);
    dt.setSeconds(dt.getSeconds() + 3600); // duration 300s
    const endTime = Math.floor(dt.getTime() / 1000);

    const minAmount = parseEther("0.5").toString();
    const maxAmount = parseEther("5").toString();

    const sig = await sign(alice.address, 0, 1, startTime, endTime, minAmount, maxAmount);

    const tx1 = await fightbetting
      .connect(alice)
      .createBetting(0, 1, startTime, endTime, minAmount, maxAmount, sig);
    await tx1.wait();

    const result = await fightbetting.bettingState(0);
    expect(result.bettorCount1.toNumber()).to.eq(0);
    expect(result.bettorCount2.toNumber()).to.eq(0);
    expect(parseFloat(formatEther(result.totalPrice1.toString()))).to.eq(0);
    expect(parseFloat(formatEther(result.totalPrice2.toString()))).to.eq(0);
  });

  it("Amount may be between min and max", async () => {
    await expect(
      fightbetting.connect(alice).bettOne(0, true, {
        value: parseEther("0.2"),
      }),
    ).to.be.revertedWith("FightBetting:TOO_SMALL_AMOUNT");

    await expect(
      fightbetting.connect(alice).bettOne(0, true, {
        value: parseEther("6"),
      }),
    ).to.be.revertedWith("FightBetting:TOO_MUCH_AMOUNT");
  });

  it("Alice bets first fighter with 1 eth", async () => {
    const tx1 = await fightbetting.connect(alice).bettOne(0, true, {
      value: parseEther("1"),
    });

    await tx1.wait();

    const bettingState = await fightbetting.bettingState(0);
    expect(bettingState.bettorCount1.toNumber()).to.eq(1);
    expect(parseFloat(formatEther(bettingState.totalPrice1.toString()))).to.eq(1);
  });

  it("Bob bets first fighter with 2 eth", async () => {
    const tx1 = await fightbetting.connect(bob).bettOne(0, true, {
      value: parseEther("2"),
    });

    await tx1.wait();

    const bettingState = await fightbetting.bettingState(0);
    expect(bettingState.bettorCount1.toNumber()).to.eq(2);
    expect(parseFloat(formatEther(bettingState.totalPrice1.toString()))).to.eq(3);
  });

  it("Vault bets second fighter with 2 eth", async () => {
    const tx1 = await fightbetting.connect(bob).bettOne(0, false, {
      value: parseEther("2"),
    });

    await tx1.wait();

    const bettingState = await fightbetting.bettingState(0);
    expect(bettingState.bettorCount2.toNumber()).to.eq(1);
    expect(parseFloat(formatEther(bettingState.totalPrice2.toString()))).to.eq(2);
  });

  it("Betting is finished and rewarded to winner", async () => {
    expect(parseFloat(formatEther(await ethers.provider.getBalance(fightbetting.address)))).to.eq(5);

    // send time to over
    await network.provider.send("evm_increaseTime", [3601]);
    await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp

    const tx1 = await fightbetting.connect(alice).finishBetting(0, true);
    await tx1.wait();

    expect(parseFloat(formatEther(await ethers.provider.getBalance(fightbetting.address)))).to.eq(0.25);
  });
});
