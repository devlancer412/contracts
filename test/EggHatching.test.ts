import { expect } from "./chai-setup";
import { deployments } from "hardhat";
import {
  Gaff__factory,
  Gem__factory,
  RoosterEggHatching__factory,
  RoosterEgg__factory,
  Rooster__factory,
} from "../types";
import { Ship } from "../utils";
import { arrayify, solidityKeccak256, splitSignature } from "ethers/lib/utils";

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
    ["address", "uint8[]", "uint256[]", "uint256[]"],
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

describe("Egg hatching test", () => {
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
});
