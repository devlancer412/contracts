import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { fromBN, Ship, toBN } from "../utils";
import {
  ERC721,
  GRP,
  GRP__factory,
  GWITToken,
  GWITToken__factory,
  Marketplace,
  Marketplace__factory,
  MasterChef,
  MasterChef__factory,
  Rooster,
  Rooster__factory,
} from "../types";
import { generate_claim, SignedClaim } from "../utils/claims";
import { BigNumber, ContractReceipt, Wallet } from "ethers";
import { deployments } from "hardhat";
import { parseSpecial } from "../utils/parseSpecial";
import { HardhatRuntimeEnvironment } from "hardhat/types";

chai.use(solidity);
const { expect } = chai;
const supply_size = parseSpecial("1bi|18");

let ship: Ship;
let hre: HardhatRuntimeEnvironment;
let marketplace: Marketplace;
let gwit: GWITToken;
let rooster: Rooster;

let owner: SignerWithAddress;
let seller: SignerWithAddress;
let buyer: SignerWithAddress;

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["mocks", "grp", "gwit", "marketplace", "nfts", "gwit_init"]);

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

describe("Marketplace test", () => {
  before(async () => {
    const scaffold = await setup();
    const { accounts } = scaffold;
    owner = scaffold.users[0];
    seller = scaffold.users[1];
    buyer = scaffold.users[2];

    marketplace = await scaffold.ship.connect(Marketplace__factory);
    gwit = await scaffold.ship.connect(GWITToken__factory);
    rooster = await scaffold.ship.connect(Rooster__factory);
    console.log("Marketplace Address", marketplace.address);
    console.log("Press any key to continue");
    await keypress();

    await rooster.grantMinterRole(seller.address);
    await gwit.transfer(seller.address, 10_000);
    await gwit.transfer(buyer.address, 10_000);
    await marketplace.setAllowedToken(rooster.address, true);
  });

  for (let i = 0; i < 10; i++) {
    describe("Listing of NFT", async () => {
      let nftId: BigNumber;
      let listingId: BigNumber;
      const price: BigNumber = toBN(Math.floor(Math.random() * 100));
      const should_sell = (Math.random() * 1000) % 2 > 1;

      it("Should mint a rooster", async () => {
        const breed = Math.floor((Math.random() * 1000) % 10);
        const rx: ContractReceipt = await (await rooster.connect(seller).mint(seller.address, breed)).wait();

        rx.events?.forEach((ev) => {
          if (ev.event === "Transfer" && ev.args?.to === seller.address) {
            nftId = ev.args.id;
          }
        });
        await expect(nftId.toString()).to.not.eq("");
      });

      it("Should have nft transferred to the marketplace", async () => {
        await rooster.connect(seller).approve(marketplace.address, nftId);
        const tx = await rooster.getApproved(nftId);
        await expect(tx).to.equal(marketplace.address);
      });

      it("Should not allow non owner to list the nft", async () => {
        await expect(marketplace.makeListing(rooster.address, nftId, 1, 0, false)).to.be.revertedWith(
          "WRONG_FROM",
        );
      });

      it("Should list the nft", async () => {
        const tx = await marketplace.connect(seller).makeListing(rooster.address, nftId, 1, 0, false);
        const rx = await tx.wait();

        rx.events?.forEach((ev) => {
          if (ev.event === "Listed" && ev.args?.owner === seller.address) {
            listingId = ev.args.listingId;
          }
        });
        await expect(listingId.toString()).to.not.eq("");
      });

      it("Should not be live", async () => {
        await expect(await marketplace.isLive(listingId)).to.eq(false);
        await expect(marketplace.connect(buyer).purchase(listingId, 1)).to.be.revertedWith(
          "listing is not live",
        );
      });

      it("Should set the price and emit Live", async () => {
        await expect(await marketplace.connect(seller).setPrice(listingId, price))
          .to.emit(marketplace, "Live")
          .withArgs(listingId, price);
      });

      it("Should have the right listing information", async () => {
        const tx = await marketplace.getListing(listingId);
        expect(tx.token).to.equal(rooster.address);
        expect(tx.tokenId).to.equal(nftId);
        expect(tx.price).to.eq(price);
        expect(tx.owner).to.eq(seller.address);
        expect(tx.fungible).to.eq(false);
        expect(tx.inactive).to.eq(false);
      });

      it("Should not allow double relisting", async () => {
        await expect(
          marketplace.connect(seller).makeListing(rooster.address, nftId, 1, 0, false),
        ).to.be.revertedWith("WRONG_FROM");
      });

      it("Should revert purchase with insufficient funds", async () => {
        await expect(marketplace.connect(buyer).purchase(listingId, 1)).to.be.revertedWith(
          "ERC20: insufficient allowance",
        );
      });

      it("Should proceed purchase with sufficient funds", async () => {
        if (!should_sell) {
          return;
        }
        const listing = await marketplace.getListing(listingId);
        await gwit.connect(buyer).approve(marketplace.address, listing.price);

        await expect(await gwit.allowance(buyer.address, marketplace.address)).to.eq(listing.price);

        const tx = await marketplace.connect(buyer).purchase(listingId, 1);
        await expect(tx).to.emit(marketplace, "Sold");
      });

      it("Should transfer the nft to the buyer", async () => {
        if (!should_sell) {
          return;
        }
        await expect(await rooster.ownerOf(nftId)).to.equal(buyer.address);
      });
    });
  }

  describe("Listing of ERC1155", async () => {
    it("TODO: Should succ", async () => {
      await expect(true).to.be.true;
    });
  });
});
