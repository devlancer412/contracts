import { BigNumber } from "ethers";
import { FightBetting__factory, GWITToken__factory, GWITToken, FightBetting } from "../types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployments, network } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { Ship } from "../utils";
import {
  arrayify,
  formatEther,
  parseBytes32String,
  solidityKeccak256,
  splitSignature,
} from "ethers/lib/utils";
import { Accounts } from "../utils/Ship";
import { parseSpecial } from "../utils/parseSpecial";

chai.use(solidity);
const { expect } = chai;
const supply_size = parseSpecial("1bi|18");

let ship: Ship;
let fightbetting: FightBetting;
let gwit: GWITToken;
let alice: SignerWithAddress;
let bob: SignerWithAddress;
let vault: SignerWithAddress;
let accounts: Accounts;
let gwitInitor: SignerWithAddress;

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["fightbetting", "gwit"]);

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
) => {
  const hash = solidityKeccak256(
    ["address", "uint256", "uint256", "uint32", "uint32", "uint256", "uint256", "address"],
    [to, fighter1, fighter2, startTime, endTime, minAmount, maxAmount, tokenAddr],
  );
  const sig = await accounts.signer.signMessage(arrayify(hash));
  const { r, s, v } = splitSignature(sig);
  return {
    r,
    s,
    v,
  };
};

const signFinish = async (to: string, bettingId: number, result: boolean) => {
  const hash = solidityKeccak256(["address", "uint256", "bool"], [to, bettingId, result]);
  const sig = await accounts.signer.signMessage(arrayify(hash));
  const { r, s, v } = splitSignature(sig);
  return {
    r,
    s,
    v,
  };
};

const swapArray = (arr: Array<any>, i: number, j: number) => {
  [arr[i], arr[j]] = [arr[j], arr[i]];
};

describe("FightBetting test", () => {
  before(async () => {
    const scaffold = await setup();

    alice = scaffold.accounts.alice;
    bob = scaffold.accounts.bob;
    vault = scaffold.accounts.vault;

    accounts = scaffold.accounts;

    fightbetting = await scaffold.ship.connect(FightBetting__factory);
    gwit = await scaffold.ship.connect(GWITToken__factory);

    gwitInitor = scaffold.users[0];
    console.log(await gwit.balanceOf(gwitInitor.address));
  });

  it("Initialize gwit token", async () => {
    const res = await gwit.initialSupply();
    expect(res).to.eq(supply_size);

    await gwit.connect(gwitInitor).transfer(alice.address, 1000);
    expect(await gwit.balanceOf(alice.address)).to.eq(1000);
    await gwit.connect(gwitInitor).transfer(bob.address, 1000);
    expect(await gwit.balanceOf(bob.address)).to.eq(1000);
    await gwit.connect(gwitInitor).transfer(vault.address, 1000);
    expect(await gwit.balanceOf(vault.address)).to.eq(1000);
  });

  it("Set signer", async () => {
    await fightbetting.grantRole("SIGNER", accounts.signer.address);
    expect(await fightbetting.hasRole("SIGNER", accounts.signer.address)).to.be.equal(true);
  });

  it("Alice creates a betting", async () => {
    const dt = new Date();
    const startTime = Math.floor(dt.getTime() / 1000);
    dt.setSeconds(dt.getSeconds() + 3600); // duration 300s
    const endTime = Math.floor(dt.getTime() / 1000);

    const minAmount = "100";
    const maxAmount = "5000";

    const sig = await signCreate(alice.address, 0, 1, startTime, endTime, minAmount, maxAmount, gwit.address);

    const tx1 = await fightbetting
      .connect(alice)
      .createBetting(0, 1, startTime, endTime, minAmount, maxAmount, gwit.address, sig);
    await tx1.wait();

    const result = await fightbetting.getBettingState(0);
    expect(result.bettorCount1.toNumber()).to.eq(0);
    expect(result.bettorCount2.toNumber()).to.eq(0);
    expect(parseFloat(formatEther(result.totalAmount1.toString()))).to.eq(0);
    expect(parseFloat(formatEther(result.totalAmount2.toString()))).to.eq(0);
  });

  it("Amount may be between min and max", async () => {
    await expect(fightbetting.connect(alice).bettOne(0, true, 10)).to.be.revertedWith(
      "FightBetting:TOO_SMALL_AMOUNT",
    );

    await expect(fightbetting.connect(alice).bettOne(0, true, 10000)).to.be.revertedWith(
      "FightBetting:TOO_MUCH_AMOUNT",
    );
  });

  it("Alice bets first fighter with 100 GWIT", async () => {
    await gwit.connect(alice).approve(fightbetting.address, 100);
    const tx1 = await fightbetting.connect(alice).bettOne(0, true, 100);

    await tx1.wait();

    const bettingState = await fightbetting.getBettingState(0);
    expect(bettingState.bettorCount1.toNumber()).to.eq(1);
    expect(bettingState.totalAmount1.toNumber()).to.eq(100);
  });

  it("Bob bets first fighter with 200 GWIT", async () => {
    await gwit.connect(bob).approve(fightbetting.address, 200);
    const tx1 = await fightbetting.connect(bob).bettOne(0, true, 200);

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
    const tx1 = await fightbetting.connect(vault).bettOne(0, false, 300);

    await tx1.wait();

    const bettingState = await fightbetting.getBettingState(0);
    expect(bettingState.bettorCount2.toNumber()).to.eq(1);
    expect(bettingState.totalAmount2.toNumber()).to.eq(300);
  });

  it("Bob can't bet again", async () => {
    await gwit.connect(bob).approve(fightbetting.address, 200);
    await expect(fightbetting.connect(bob).bettOne(0, true, 200)).to.be.revertedWith(
      "FightBetting:ALREADY_BET",
    );
  });

  it("Betting is finished and rewarded to winner", async () => {
    // send time to over
    await network.provider.send("evm_increaseTime", [3601]);
    await network.provider.send("evm_mine"); // this one will have 02:00 PM as its timestamp

    const sig = await signFinish(alice.address, 0, true);
    const tx1 = await fightbetting.connect(alice).finishBetting(0, true, sig);
    await tx1.wait();
  });

  it("Can't bet after finished", async () => {
    await expect(fightbetting.connect(gwitInitor).bettOne(0, false, 300)).to.be.revertedWith(
      "FightBetting:ALREADY_FINISHED",
    );
  });

  it("Alice and bob withdraws their token", async () => {
    const amountOfAlice = await gwit.balanceOf(alice.address);
    const amountOfBob = await gwit.balanceOf(bob.address);

    expect(await gwit.balanceOf(fightbetting.address)).to.be.eq(600);

    await fightbetting.connect(alice).withdrawReward(0);
    await fightbetting.connect(bob).withdrawReward(0);

    expect(await gwit.balanceOf(alice.address)).to.be.eq(amountOfAlice.add(176)); // 600 * 88 / 100 / 3 = 176
    expect(await gwit.balanceOf(bob.address)).to.be.eq(amountOfBob.add(352)); // (600 * 88 / 100) * 2 / 3 = 352
    expect(await gwit.balanceOf(fightbetting.address)).to.be.eq(72); // 600 * 12 / 100 = 72
  });

  it("Get lucky winner data", async () => {
    await fightbetting.connect(alice).withdrawLuckyWinnerReward(0);
    await fightbetting.connect(bob).withdrawLuckyWinnerReward(0);
    expect(await gwit.balanceOf(fightbetting.address)).to.be.eq(60);
  });

  it("Provably test", async () => {
    const seedResult = await fightbetting.connect(alice).getSeeds(0);
    const stateResult = await fightbetting.getBettingState(0);

    const clientSeeds: FightBetting.ClientSeedDataStructOutput[] = seedResult.clientSeeds;
    // hash client seed
    let hashed: Array<any> = [];
    hashed = clientSeeds.map((seedData) => {
      return {
        ...seedData,
        seed: solidityKeccak256(
          ["bytes32", "bytes32", "uint256", "uint256", "bool"],
          [
            seedResult.serverSeed,
            seedData.seed,
            stateResult.bettorCount1.add(stateResult.bettorCount2),
            stateResult.totalAmount1.add(stateResult.totalAmount2),
            !stateResult.witch,
          ],
        ),
      };
    });
    // rearrange client seeds
    for (let i = 0; i < hashed.length; i++) {
      for (let j = i + 1; j < hashed.length; j++) {
        if (!BigNumber.from(clientSeeds[i].seed).sub(BigNumber.from(hashed[j].seed)).isNegative()) {
          const temp = hashed[i];
          hashed[i] = hashed[j];
          hashed[j] = temp;
        }
      }
    }

    // getting winners
    const startIndex = BigNumber.from(seedResult.serverSeed).mod(seedResult.clientSeeds.length);

    const luckyResult = await fightbetting.connect(alice).getLuckyWinner(0);
    // compare
    expect(luckyResult.winners[0]).to.eq(seedResult.clientSeeds[startIndex.toNumber()].who);
    expect(luckyResult.winners[1]).to.eq(
      seedResult.clientSeeds[startIndex.add(1).mod(seedResult.clientSeeds.length).toNumber()].who,
    );
    expect(luckyResult.winners[2]).to.eq(
      seedResult.clientSeeds[startIndex.add(2).mod(seedResult.clientSeeds.length).toNumber()].who,
    );
  });
});
