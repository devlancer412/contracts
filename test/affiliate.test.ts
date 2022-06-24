import { Contract, BigNumber } from "ethers";
import { arrayify, Interface, solidityKeccak256, splitSignature } from "ethers/lib/utils";
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

let ship: Ship;
let usdc: MockUsdc;
let affiliate: Affiliate;
let eggSale: RoosterEggSale;
let egg: RoosterEgg;
let signer: SignerWithAddress;
let alice: SignerWithAddress;
let bob: SignerWithAddress;
let vault: SignerWithAddress;

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

const realAbi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
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
    name: "buyEggWithAffiliate",
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
    name: "buyEggWithAffiliate",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

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

    ship = scaffold.ship;
    usdc = await ship.connect(MockUsdc__factory);
    affiliate = await ship.connect(Affiliate__factory);
    eggSale = await ship.connect(RoosterEggSale__factory);
    egg = await ship.connect(RoosterEgg__factory);

    bob = scaffold.accounts.bob;
    alice = scaffold.accounts.alice;
    signer = scaffold.accounts.signer;
    vault = scaffold.accounts.vault;

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
    const distributorUsdcAmount = await usdc.balanceOf(vault.address);

    const proxyContract = new Contract(affiliate.address, abi, ship.provider);
    const iRealFace = new Interface(realAbi);

    await usdc.connect(alice).approve(eggSale.address, 500);
    const tx = await proxyContract.connect(alice).buyEggWithAffiliate(
      alice.address, // to address to send egg
      10, // amount of egg
      eggSale.address, // eggsale contract address
      bob.address, // affiliate address
      iRealFace.getSighash("buyEggWithAffiliate"), // function selector to replace
    );
    await tx.wait();

    const proxyEvent = await proxyContract.provider.getLogs({ address: affiliate.address });

    expect(proxyEvent.length).to.eq(1);
    expect(BigNumber.from(proxyEvent[0].data)).to.eq(BigNumber.from(10));
    expect(BigNumber.from(proxyEvent[0].topics[1])).to.eq(BigNumber.from(bob.address));

    expect(await usdc.balanceOf(alice.address)).to.eq(aliceUsdcAmount.sub(500));
    expect(await usdc.balanceOf(vault.address)).to.eq(distributorUsdcAmount.add(500));
    expect(await egg.balanceOf(alice.address)).to.eq(aliceEggAmount.add(10));
  });
});
