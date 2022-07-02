import { Contract, BigNumber } from "ethers";
import { AbiCoder, arrayify, Interface, solidityKeccak256, splitSignature } from "ethers/lib/utils";
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
  Store,
  Store__factory,
  Rooster,
  Rooster__factory,
  GWITToken,
  GWITToken__factory,
} from "../types";
import { deployments } from "hardhat";

import { abiEgg, abiStore, realAbiEgg, realAbiStore } from "./AffiliateAbis.json";

chai.use(solidity);
const { expect } = chai;

let ship: Ship;
let usdc: MockUsdc;
let affiliate: Affiliate;
let eggSale: RoosterEggSale;
let store: Store;
let egg: RoosterEgg;
let rooster: Rooster;
let gwit: GWITToken;
let signer: SignerWithAddress;
let alice: SignerWithAddress;
let bob: SignerWithAddress;
let vault: SignerWithAddress;
let deployer: SignerWithAddress;

let seller: SignerWithAddress;
let buyer: SignerWithAddress;

const setup = deployments.createFixture(async (hre) => {
  const ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture([
    "mocks",
    "eggsale",
    "egg",
    "grp",
    "gwit",
    "marketplace",
    "nfts",
    "gwit_init",
    "store",
    "affiliate",
  ]);

  return {
    ship,
    accounts,
    users,
  };
});

const sign = async (sender: string, to: string, redeem_codes: number[], value: number) => {
  const hash = solidityKeccak256(
    ["address", "address", "uint256[]", "uint256"],
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
    rooster = await ship.connect(Rooster__factory);
    gwit = await ship.connect(GWITToken__factory);
    store = await ship.connect(Store__factory);
    egg = await ship.connect(RoosterEgg__factory);

    bob = scaffold.accounts.bob;
    alice = scaffold.accounts.alice;
    signer = scaffold.accounts.signer;
    vault = scaffold.accounts.vault;
    deployer = scaffold.accounts.deployer;

    seller = scaffold.users[1];
    buyer = scaffold.users[2];

    await usdc.mint(signer.address, 100000);
    await affiliate.grantRole("DISTRIBUTOR", signer.address);
    await usdc.connect(signer).approve(affiliate.address, 10000);

    await rooster.grantRole("MINTER", seller.address);
    await gwit.transfer(seller.address, 10_000_000);
    await gwit.transfer(buyer.address, 10_000_000);
    await rooster.grantRole("MINTER", store.address);

    await egg.connect(deployer).transferOwnership(eggSale.address);
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
    await eggSale.setAffiliateData(affiliate.address, 50);
    const aliceUsdcAmount = await usdc.balanceOf(alice.address);
    const aliceEggAmount = await egg.balanceOf(alice.address);
    const distributorUsdcAmount = await usdc.balanceOf(vault.address);
    const affiliateId = solidityKeccak256(["address"], [bob.address]);

    const proxyContract = new Contract(affiliate.address, abiEgg, ship.provider);
    const iRealFace = new Interface(realAbiEgg);

    await usdc.connect(alice).approve(eggSale.address, 500);
    const tx = await proxyContract.connect(alice).buyEggWithAffiliate(
      alice.address, // to address to send egg
      10, // amount of egg
      eggSale.address, // eggsale contract address
      affiliateId, // affiliate address
      iRealFace.getSighash("buyEggWithAffiliate"), // function selector to replace
    );
    const receipt = await tx.wait();

    const events = receipt?.events;
    const affiliateEvents = events.filter((event: any) => event?.address == affiliate.address);
    expect(affiliateEvents.length).to.eq(1);
    const data = affiliateEvents[0]?.data;
    const abicoder = new AbiCoder();
    const decodedData = abicoder.decode(["address", "uint256"], data);
    expect(decodedData[0]).to.eq(alice.address);
    expect(decodedData[1]).to.eq(10);

    const indexedData = affiliateEvents[0]?.topics;
    expect(abicoder.decode(["uint256"], indexedData[1])[0]).to.eq(affiliateId);
    expect(abicoder.decode(["address"], indexedData[2])[0]).to.eq(eggSale.address);
    expect(abicoder.decode(["address"], indexedData[3])[0]).to.eq(alice.address);

    expect(await usdc.balanceOf(alice.address)).to.eq(aliceUsdcAmount.sub(500));
    expect(await usdc.balanceOf(vault.address)).to.eq(distributorUsdcAmount.add(500));
    expect(await egg.balanceOf(alice.address)).to.eq(aliceEggAmount.add(10));
  });

  describe("Store test", () => {
    let listingId: number;
    before(async () => {
      await store.setAffiliateAddress(affiliate.address);
      await store.setAllowedLister(seller.address, true);
    });

    it("Add list to store", async () => {
      const tokenType = 3; // ERC721EX
      const tokenAddress = rooster.address;
      const tokenId = 0; // Only for ERC1155 use
      const amount = 1; // Only mint 1 egg
      const price = 500; // each mint costs 100 of the operating token
      const maxval = 10; // the maximum value to pass to the unique parameter, leave to 0 to send a random uint256 value [0x00_00...00, 0xFF_FF...FF];
      const rx = await (
        await store.connect(seller).makeListing(tokenType, tokenAddress, tokenId, amount, price, maxval)
      ).wait();

      const ev = rx.events?.find((event) => event.event === "Listed");
      listingId = ev?.args?.listingId;
      expect(listingId).to.not.eql(-1);
    });

    it("Store test", async () => {
      const buyerGwitAmount = await gwit.balanceOf(buyer.address);
      const buyerItemAmount = await rooster.balanceOf(buyer.address);
      const distributorGwitAmount = await gwit.balanceOf(vault.address);
      const affiliateId = solidityKeccak256(["address"], [bob.address]);

      const proxyContract = new Contract(affiliate.address, abiStore, ship.provider);
      const iRealFace = new Interface(realAbiStore);

      await gwit.connect(buyer).approve(store.address, 600);
      const tx = await proxyContract.connect(buyer).buyItemWithAffiliate(
        buyer.address, // to address to send egg
        listingId, // list id
        1, // amount of egg
        store.address, // eggsale contract address
        affiliateId, // affiliate address
        iRealFace.getSighash("buyItemWithAffiliate"), // function selector to replace
      );
      const receipt = await tx.wait();

      const events = receipt?.events;
      const affiliateEvents = events.filter((event: any) => event?.address == affiliate.address);
      expect(affiliateEvents.length).to.eq(1);
      const data = affiliateEvents[0]?.data;

      const abicoder = new AbiCoder();
      const decodedData = abicoder.decode(["address", "uint256", "uint256"], data);
      expect(decodedData[0]).to.eq(buyer.address);
      expect(decodedData[1]).to.eq(listingId);
      expect(decodedData[2]).to.eq(1);

      const indexedData = affiliateEvents[0]?.topics;
      expect(abicoder.decode(["uint256"], indexedData[1])[0]).to.eq(affiliateId);
      expect(abicoder.decode(["address"], indexedData[2])[0]).to.eq(store.address);
      expect(abicoder.decode(["address"], indexedData[3])[0]).to.eq(buyer.address);

      expect(await gwit.balanceOf(buyer.address)).to.eq(buyerGwitAmount.sub(500));
      expect(await gwit.balanceOf(seller.address)).to.eq(distributorGwitAmount.add(500));
      expect(await rooster.balanceOf(buyer.address)).to.eq(buyerItemAmount.add(1));
    });
  });
});
