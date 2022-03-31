import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { fromBN, Ship, toBN } from "../utils";
import {
  ERC721,
  Gem,
  Gem__factory,
  GWITToken,
  GWITToken__factory,
  Rooster,
  Rooster__factory,
  Store,
  Store__factory,
} from "../types";
import { generate_claim, SignedClaim } from "../utils/claims";
import { BigNumber, BigNumberish, ContractReceipt, Wallet } from "ethers";
import { deployments } from "hardhat";
import { parseSpecial } from "../utils/parseSpecial";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import exp from "constants";
import { mkdirSync, writeFile } from "fs";
import { resolve } from "path";
import { homedir } from "os";

chai.use(solidity);
const { expect } = chai;

let ship: Ship;
let hre: HardhatRuntimeEnvironment;
let store: Store;
let gwit: GWITToken;
let rooster: Rooster;
let gem: Gem;

let signer: SignerWithAddress;
let seller: SignerWithAddress;
let buyer: SignerWithAddress;

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["mocks", "grp", "gwit", "marketplace", "nfts", "gwit_init", "store"]);

  return {
    ship,
    accounts,
    users,
  };
});

describe("Store test", () => {
  before(async () => {
    const scaffold = await setup();
    signer = scaffold.users[0];
    seller = scaffold.users[1];
    buyer = scaffold.users[2];

    store = await scaffold.ship.connect(Store__factory);
    gwit = await scaffold.ship.connect(GWITToken__factory);
    rooster = await scaffold.ship.connect(Rooster__factory);
    gem = await scaffold.ship.connect(Gem__factory);

    await rooster.grantMinterRole(seller.address);
    await gwit.transfer(seller.address, 10_000_000);
    await gwit.transfer(buyer.address, 10_000_000);

    await gem.grantMinterRole(store.address);
    await rooster.grantMinterRole(store.address);
    await store.setSigner(signer.address, true);
    await store.setAllowedLister(seller.address, true);

    // Write addresses to some file
    // To be picked up by the backend while testing
    const base = [homedir(), ".temp", "metadhana", "store", "localhost"];
    const addresses = [
      ["store", store.address],
      ["gwit", gwit.address],
      ["signer", signer.address],
      ["seller", seller.address],
      ["buyer", buyer.address],
      ["rooster", rooster.address],
      ["gem", gem.address],
    ];
    addresses.forEach((v) => {
      // const target = base + `/${v[0]}`
      mkdirSync(resolve(...base), { recursive: true });
      const target = resolve(...base, v[0]);
      writeFile(target, v[1], { flag: "w+" }, async (err) => {
        console.log(`Writing '${v[1]}' to '${target}'`);
        if (err) {
          console.log(" -> ", err);
        }
      });
    });
  });

  describe("Listing ERC721Ex Token", async () => {
    let listingId: BigNumberish = -1;
    let tx: ContractReceipt;

    it("should list token", async () => {
      const tokenType = 3; // ERC721EX
      const tokenAddress = rooster.address;
      const tokenId = 0; // Only for ERC1155 use
      const amount = 1; // Only mint 1 rooster
      const price = 100; // each mint costs 100 of the operating token
      const maxval = 10; // the maximum value to pass to the unique parameter, leave to 0 to send a random uint256 value [0x00_00...00, 0xFF_FF...FF];
      const rx = await (
        await store.connect(seller).makeListing(tokenType, tokenAddress, tokenId, amount, price, maxval)
      ).wait();

      const ev = rx.events?.find((event) => event.event === "Listed");
      listingId = ev?.args?.listingId;
      await expect(listingId).to.not.eql(-1);
    });

    describe("purchase flow", async () => {
      const transfer_amount = 100;
      const amount = 1;

      it("should transfer tokens", async () => {
        // Frontend Transfer
        tx = await (await gwit.connect(buyer).approve(store.address, transfer_amount)).wait();
        await expect(await gwit.allowance(buyer.address, store.address)).to.eq(transfer_amount);
      });

      it("should purchase", async () => {
        const old_balance = await rooster.balanceOf(buyer.address);
        // Backend Claim Assembly
        const nonce = BigNumber.from(Date.now());
        const last = await store.last_purchase(buyer.address);
        const claim = await generate_claim(signer, buyer.address, last, nonce);

        const purchaseTx = await store.connect(buyer).purchase(buyer.address, [listingId], [amount], claim);
        await expect(purchaseTx).to.emit(store, "Sold").withArgs(listingId, buyer.address, amount);

        await expect(await rooster.balanceOf(buyer.address)).to.eq(old_balance.add(1));
        await expect(await store.stocks(listingId)).to.eq(0);
      });
    });
  });

  describe("Listing ERC1155 Token", async () => {
    let listingId: BigNumberish = -1;
    let tx: ContractReceipt;
    const tokenId = 3; // Only for ERC1155 use

    it("should list token", async () => {
      const tokenType = 0; // ERC1155
      const tokenAddress = gem.address;
      const amount = 50; // Only mint 50 gem@3 tokens
      const price = 6; // each mint costs 6 of the operating token
      const maxval = 0; // unused for non EXT tokens
      const rx = await (
        await store.connect(seller).makeListing(tokenType, tokenAddress, tokenId, amount, price, maxval)
      ).wait();

      const ev = rx.events?.find((event) => event.event === "Listed");
      listingId = ev?.args?.listingId;
      await expect(listingId).to.not.eql(-1);
    });

    describe("purchase flow", async () => {
      const transfer_amount = 60;
      const amount = 10;

      it("should transfer tokens", async () => {
        // Frontend Transfer
        tx = await (await gwit.connect(buyer).approve(store.address, transfer_amount)).wait();
        await expect(await gwit.allowance(buyer.address, store.address)).to.eq(transfer_amount);
      });

      it("should purchase", async () => {
        const old_balance = await gem.balanceOf(buyer.address, tokenId);
        // Backend Claim Assembly
        const nonce = BigNumber.from(Date.now());
        const last = await store.last_purchase(buyer.address);
        const claim = await generate_claim(signer, buyer.address, last, nonce);

        // Purchase
        const purchaseTx = await store.connect(buyer).purchase(buyer.address, [listingId], [amount], claim);
        await expect(purchaseTx).to.emit(store, "Sold").withArgs(listingId, buyer.address, amount);

        await expect(await gem.balanceOf(buyer.address, tokenId)).to.eq(old_balance.add(amount));
        await expect(await store.stocks(listingId)).to.eq(40);
      });
    });
  });
});
