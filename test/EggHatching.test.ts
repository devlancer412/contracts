import { expect } from "./chai-setup";
import { deployments } from "hardhat";
import {
  Gaff__factory,
  Gem__factory,
  RoosterEggHatching__factory,
  RoosterEgg__factory,
  Rooster__factory,
} from "../types";
import { Ship, toBNArray } from "../utils";
import { arrayify, solidityKeccak256, splitSignature } from "ethers/lib/utils";
import { constants } from "ethers";

const setup = deployments.createFixture(async (hre) => {
  const { connect, accounts, users } = await Ship.init(hre);
  await deployments.fixture(["mocks", "egg", "nfts", "hatching"]);

  const egg = await connect(RoosterEgg__factory);
  const rooster = await connect(Rooster__factory);
  const gaff = await connect(Gaff__factory);
  const gem = await connect(Gem__factory);
  const hatching = await connect(RoosterEggHatching__factory);

  return {
    egg,
    rooster,
    gaff,
    gem,
    hatching,
    accounts,
    users,
  };
});

const sign = async (user: string, breeds: number[], gaffAmounts: number[], gemIds: number[]) => {
  const { accounts } = await Ship.init();
  const hash = solidityKeccak256(
    ["address", "uint256[]", "uint256[]", "uint256[]"],
    [user, breeds, gaffAmounts, gemIds],
  );
  const sig = await accounts.signer.signMessage(arrayify(hash));
  const { r, s, v } = splitSignature(sig);
  return {
    r,
    s,
    v,
  };
};

const emptySig = {
  r: constants.HashZero,
  s: constants.HashZero,
  v: 0,
};

describe("Egg hatching test", () => {
  before(async () => {
    //Create initial fixture here
    await setup();
  });

  it("Hatches", async () => {
    const { egg, rooster, gaff, gem, hatching, accounts } = await setup();
    const { alice } = accounts;

    //Mint 1 egg
    await egg.mintEggs(alice.address, 1);

    //Check balance
    expect(await egg.balanceOf(alice.address)).to.eq(1);

    //Give opertor approval
    await egg.connect(alice).setApprovalForAll(hatching.address, true);

    //Hatch egg
    const breeds = [0];
    const gaffAmounts = [1, 0, 0];
    const gemIds = [3];
    const sig = await sign(alice.address, breeds, gaffAmounts, gemIds);
    await expect(hatching.connect(alice).hatch(alice.address, [1], breeds, gaffAmounts, gemIds, sig))
      .to.emit(hatching, "EggsHatched")
      .withArgs(alice.address, [1]);

    //Check balances
    expect(await egg.balanceOf(alice.address)).to.eq(0);
    expect(await rooster.balanceOf(alice.address)).to.eq(1);
    expect(await gaff.balanceOf(alice.address, 0)).to.eq(1);
    expect(await gem.balanceOf(alice.address, 3)).to.eq(1);
  });

  it("Hatches 10eggs", async () => {
    const { egg, rooster, gaff, gem, hatching, accounts } = await setup();
    const { alice } = accounts;

    await egg.mintEggs(alice.address, 10);
    expect(await egg.balanceOf(alice.address)).to.eq(10);

    await egg.connect(alice).setApprovalForAll(hatching.address, true);

    const eggs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    const breeds = [3, 2, 5, 6, 0, 9, 4, 2, 1, 7];
    const gaffAmounts = [2, 5, 3];
    const gemIds = [7, 1, 2, 4, 9, 10, 5, 6, 0, 3];
    const sig = await sign(alice.address, breeds, gaffAmounts, gemIds);
    await expect(hatching.connect(alice).hatch(alice.address, eggs, breeds, gaffAmounts, gemIds, sig))
      .to.emit(hatching, "EggsHatched")
      .withArgs(alice.address, eggs);

    expect(await egg.balanceOf(alice.address)).to.eq(0);
    expect(await rooster.balanceOf(alice.address)).to.eq(10);
    const threeAlice = new Array<string>(3).fill(alice.address);
    expect(await gaff.balanceOfBatch(threeAlice, [0, 1, 2])).to.deep.equal(toBNArray([2, 5, 3]));
    const tenAlice = new Array<string>(10).fill(alice.address);
    const ten1s = new Array<number>(10).fill(1);
    expect(await gem.balanceOfBatch(tenAlice, gemIds)).to.deep.equal(toBNArray(ten1s));
  });

  it("Reverts when hatched by non egg owner", async () => {
    const { egg, hatching, accounts } = await setup();
    const { alice, bob } = accounts;

    await egg.mintEggs(alice.address, 1);
    expect(await egg.balanceOf(alice.address)).to.eq(1);

    await egg.connect(alice).setApprovalForAll(hatching.address, true);

    const breeds = [0];
    const gaffAmounts = [1, 0, 0];
    const gemIds = [3];
    const sig = await sign(bob.address, breeds, gaffAmounts, gemIds);
    await expect(
      hatching.connect(bob).hatch(bob.address, [1], breeds, gaffAmounts, gemIds, sig),
    ).to.revertedWith("Invalid owner");
  });

  it("Reverts when random parameter is passed", async () => {
    const {
      egg,
      hatching,
      accounts: { alice },
    } = await setup();
    await egg.mintEggs(alice.address, 3);
    await egg.connect(alice).setApprovalForAll(hatching.address, true);

    const eggs = [1, 2, 3];
    const breeds = [0, 1, 2];
    const gaffAmounts = [1, 1, 1];
    const gemIds = [0, 1, 2];
    const sig = await sign(alice.address, breeds, gaffAmounts, gemIds);
    const promi1 = hatching.connect(alice).hatch(alice.address, eggs, breeds, gaffAmounts, gemIds, emptySig);
    const promi2 = hatching
      .connect(alice)
      .hatch(alice.address, eggs, [...breeds, 3], gaffAmounts, gemIds, sig);
    const promi3 = hatching
      .connect(alice)
      .hatch(alice.address, eggs, breeds.reverse(), gaffAmounts, gemIds, emptySig);

    await expect(promi1).to.be.revertedWith("Invalid parameter");
    await expect(promi2).to.be.revertedWith("Invalid parameter");
    await expect(promi3).to.be.revertedWith("Invalid parameter");
  });

  it("Cannot hatch when it's paused", async () => {
    const {
      hatching,
      accounts: { alice, deployer },
    } = await setup();
    await expect(hatching.connect(deployer).pause()).to.emit(hatching, "Paused");
    expect(await hatching.paused()).to.eq(true);

    const promi = hatching.connect(alice).hatch(alice.address, [], [], [], [], emptySig);
    await expect(promi).to.be.revertedWith("Pausable: paused");
  });

  it("Only owner can change signer", async () => {
    const {
      hatching,
      accounts: { alice, bob, deployer, signer },
    } = await setup();
    const promi1 = hatching.connect(alice).setSigner(bob.address);
    const promi2 = hatching.connect(deployer).setSigner(bob.address);

    await expect(promi1).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(promi2).to.emit(hatching, "UpdateSigner").withArgs(signer.address, bob.address);
  });
});
