import { arrayify, solidityKeccak256, splitSignature } from "ethers/lib/utils";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Ship } from "../utils";
import {
  MockUsdc,
  MockUsdc__factory,
  Affiliate,
  Affiliate__factory,
  RoosterEggSale,
  RoosterEggSale__factory,
  RoosterEgg,
  RoosterEgg__factory,
} from "../types";
import { deployments } from "hardhat";

chai.use(solidity);
const { expect } = chai;

let usdc: MockUsdc;
let affiliate: Affiliate;
let eggSale: RoosterEggSale;
let egg: RoosterEgg;
let signer: SignerWithAddress;
let alice: SignerWithAddress;
let bob: SignerWithAddress;

const setup = deployments.createFixture(async (hre) => {
  const ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["mocks", "affiliate", "eggsale", "egg"]);

  return {
    ship,
    accounts,
    users,
  };
});

const sign = async (sender: string, to: string, redeem_codes: number[], value: number) => {
  const hash = solidityKeccak256(
    ["address", "address", "uint64[]", "uint256"],
    [sender, to, redeem_codes, value],
  );
  const sig = await signer.signMessage(arrayify(hash));
  const { r, s, v } = splitSignature(sig);
  return {
    r,
    s,
    v,
  };
};

describe("Affiliate test", () => {
  before(async () => {
    const scaffold = await setup();

    usdc = await scaffold.ship.connect(MockUsdc__factory);
    affiliate = await scaffold.ship.connect(Affiliate__factory);
    eggSale = await scaffold.ship.connect(RoosterEggSale__factory);
    egg = await scaffold.ship.connect(RoosterEgg__factory);

    bob = scaffold.accounts.bob;
    alice = scaffold.accounts.alice;
    signer = scaffold.accounts.signer;

    await usdc.mint(signer.address, 100000);
    await affiliate.grantRole("DISTRIBUTOR", signer.address);
    await usdc.connect(signer).approve(affiliate.address, 10000);
  });

  it("alice call reward", async () => {
    const codes = [0, 1, 2, 3];
    const value = 650;

    const aliceAmount = await usdc.balanceOf(alice.address);

    const signature = await sign(signer.address, alice.address, codes, value);
    await affiliate.connect(signer).redeemCode(alice.address, codes, value, signature);

    expect(await usdc.balanceOf(alice.address)).to.eq(aliceAmount.add(650));
  });

  it("alice can't redeem again with same code", async () => {
    const codes = [0, 1, 2, 3];
    const value = 650;

    const signature = await sign(signer.address, alice.address, codes, value);
    await expect(
      affiliate.connect(signer).redeemCode(alice.address, codes, value, signature),
    ).to.be.revertedWith("Affiliate:ALREADY_REDEEMED");
  });

  it("Eggsale test", async () => {
    const aliceUsdcAmount = await usdc.balanceOf(alice.address);
    const aliceEggAmount = await egg.balanceOf(alice.address);
    const distributorUsdcAmount = await usdc.balanceOf(signer.address);

    await usdc.connect(alice).approve(affiliate.address, 500);
    const tx = await affiliate.connect(alice).buyEggWithAffiliate(alice.address, 10, bob.address);
    await tx.wait();

    expect(await usdc.balanceOf(alice.address)).to.eq(aliceUsdcAmount.sub(500));
    expect(await usdc.balanceOf(signer.address)).to.eq(distributorUsdcAmount.add(500));
    expect(await egg.balanceOf(alice.address)).to.eq(aliceEggAmount.add(10));
  });
});
