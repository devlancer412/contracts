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

const sign = async (user: string, breeds: number[], gaffTypes: number[], gemTypes: number[]) => {
  const { accounts } = await Ship.init();
  const hash = solidityKeccak256(
    ["address", "uint256[]", "uint256[]", "uint256[]"],
    [user, breeds, gaffTypes, gemTypes],
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
    const eggIds = [1];
    const breeds = [0];
    const gaffTypes = [1];
    const gemTypes = [3];
    const sig = await sign(alice.address, breeds, gaffTypes, gemTypes);
    await expect(hatching.connect(alice).hatch(alice.address, eggIds, breeds, gaffTypes, gemTypes, sig))
      .to.emit(hatching, "EggsHatched")
      .withArgs(alice.address, eggIds);

    //Check balances
    expect(await egg.balanceOf(alice.address)).to.eq(0);
    expect(await rooster.balanceOf(alice.address)).to.eq(1);
    expect(await rooster.breeds(0)).to.eq(0);
    expect(await gaff.balanceOf(alice.address)).to.eq(1);
    expect(await gaff.gaffTypes(0)).to.eq(1);
    expect(await gem.balanceOf(alice.address)).to.eq(1);
    expect(await gem.gemTypes(0)).to.eq(3);
  });

  it("Hatches 10eggs", async () => {
    const { egg, rooster, gaff, gem, hatching, accounts } = await setup();
    const { alice } = accounts;

    await egg.mintEggs(alice.address, 10);
    expect(await egg.balanceOf(alice.address)).to.eq(10);

    await egg.connect(alice).setApprovalForAll(hatching.address, true);

    const eggs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    const breeds = [3, 2, 5, 6, 0, 9, 4, 2, 1, 7];
    const gaffTypes = [4, 7, 10, 8, 6, 5, 4, 2, 1, 8];
    const gemTypes = [7, 1, 2, 4, 9, 10, 5, 6, 0, 3];
    const sig = await sign(alice.address, breeds, gaffTypes, gemTypes);
    await expect(hatching.connect(alice).hatch(alice.address, eggs, breeds, gaffTypes, gemTypes, sig))
      .to.emit(hatching, "EggsHatched")
      .withArgs(alice.address, eggs);

    expect(await egg.balanceOf(alice.address)).to.eq(0);
    expect(await rooster.balanceOf(alice.address)).to.eq(10);
    expect(await gaff.balanceOf(alice.address)).to.eq(10);
    expect(await gem.balanceOf(alice.address)).to.eq(10);
  });

  it("Reverts when hatched by non egg owner", async () => {
    const { egg, hatching, accounts } = await setup();
    const { alice, bob } = accounts;

    await egg.mintEggs(alice.address, 1);
    expect(await egg.balanceOf(alice.address)).to.eq(1);

    await egg.connect(alice).setApprovalForAll(hatching.address, true);

    const breeds = [0];
    const gaffTypes = [0];
    const gemTypes = [3];
    const sig = await sign(bob.address, breeds, gaffTypes, gemTypes);
    await expect(
      hatching.connect(bob).hatch(bob.address, [1], breeds, gaffTypes, gemTypes, sig),
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
    const gaffTypes = [1, 1, 1];
    const gemTypes = [0, 1, 2];
    const sig = await sign(alice.address, breeds, gaffTypes, gemTypes);
    const promi1 = hatching.connect(alice).hatch(alice.address, eggs, breeds, gaffTypes, gemTypes, emptySig);
    const promi2 = hatching
      .connect(alice)
      .hatch(alice.address, eggs, [...breeds, 3], gaffTypes, gemTypes, sig);
    const promi3 = hatching
      .connect(alice)
      .hatch(alice.address, eggs, breeds.reverse(), gaffTypes, gemTypes, emptySig);

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
