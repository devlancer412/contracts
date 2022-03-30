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

const keypress = async () => {
  process.stdin.setRawMode(true);
  return new Promise((resolve) =>
    process.stdin.once("data", () => {
      process.stdin.setRawMode(false);
      resolve(undefined);
    }),
  );
};

describe("Store test", () => {
  before(async () => {
    const scaffold = await setup();
    signer = scaffold.users[0];
    seller = scaffold.users[1];
    buyer = scaffold.users[2];

    store = await scaffold.ship.connect(Store__factory);
    gwit = await scaffold.ship.connect(GWITToken__factory);
    rooster = await scaffold.ship.connect(Rooster__factory);
    console.log("Store Address", store.address);
    // console.log("Press any key to continue");
    // await keypress();

    await rooster.grantMinterRole(seller.address);
    await gwit.transfer(seller.address, 10_000_000);
    await gwit.transfer(buyer.address, 10_000_000);

    await rooster.grantMinterRole(store.address);
    await store.setSigner(signer.address, true);
    await store.setAllowedLister(seller.address, true);
  });

  describe("Listing ERC721Ex Token", async () => {
    let listingId: BigNumberish = -1;
    let tx: ContractReceipt;

    it("should list token", async () => {
      const tokenType = 3; // ERC721EX
      const tokenAddress = rooster.address;
      const tokenId = 0; // Only for ERC1155 use
      const amount = 500; // Only mint 500 roosters
      const price = 100; // each mint costs 100 of the operating token
      const maxval = 10; // the maximum value to pass to the unique parameter, leave to 0 to send a random uint256 value [0x00_00...00, 0xFF_FF...FF];
      const rx = await (
        await store.connect(seller).makeListing(tokenType, tokenAddress, tokenId, amount, price, maxval)
      ).wait();

      const ev = rx.events?.find((event) => event.event === "Listed");
      console.log("Event", ev);
      listingId = ev?.args?.listingId;
      await expect(listingId).to.not.eql(-1);
    });

    describe("purchase flow", async () => {
      const transfer_amount = 100;
      const amount = 1;

      it("should transfer tokens", async () => {
        // Frontend Transfer
        tx = await (await gwit.connect(buyer).transfer(store.address, transfer_amount)).wait();
        await expect(await gwit.balanceOf(store.address)).to.eq(transfer_amount);
      });

      it("should purchase", async () => {
        const old_balance = await rooster.balanceOf(buyer.address);
        // Backend Claim Assembly
        const nonce = BigNumber.from(tx.blockHash);
        const claim = await generate_claim(signer, buyer.address, transfer_amount, nonce);

        const purchaseTx = await store.connect(buyer).purchase([listingId], [amount], claim);
        await expect(purchaseTx).to.emit(store, "Sold").withArgs(listingId, buyer.address, amount);

        await expect(await rooster.balanceOf(buyer.address)).to.eq(old_balance.add(1));
      });
    });
  });
});
