import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Rooster__factory, Scholarship__factory, Scholarship, Rooster } from "../types";
import { deployments } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { Ship } from "../utils";

chai.use(solidity);
const { expect } = chai;

let ship: Ship;
let rooster: Rooster;
let scholarship: Scholarship;
let hre: HardhatRuntimeEnvironment;
let alice: SignerWithAddress;
let bob: SignerWithAddress;
let vault: SignerWithAddress;

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["rooster", "scholarship"]);

  return {
    ship,
    accounts,
    users,
  };
});

describe("Scholarship test", () => {
  before(async () => {
    const scaffold = await setup();

    alice = scaffold.accounts.alice;
    bob = scaffold.accounts.bob;
    vault = scaffold.accounts.vault;

    rooster = await scaffold.ship.connect(Rooster__factory);
    scholarship = await scaffold.ship.connect(Scholarship__factory);

    await rooster.grantRole("MINTER", alice.address);
    await rooster.grantRole("MINTER", scholarship.address);
    await rooster.connect(alice).mint(alice.address, 0);
    await rooster.connect(alice).mint(alice.address, 0);
    await rooster.connect(alice).mint(alice.address, 0);
    await rooster.connect(alice).mint(alice.address, 0);
  });

  describe("Lending a NFT test", async () => {
    const nftId = 0;
    before(async () => {
      // Alice has a rooster.
      expect(await rooster.balanceOf(alice.address)).to.eq(4);
      expect(await rooster.totalSupply()).to.eq(4);

      expect(await rooster.ownerOf(nftId)).to.eq(alice.address);
      // Give opertor approval
      await rooster.connect(alice).setApprovalForAll(scholarship.address, true);
    });

    it("Lend request will revote when scholarship disabled.", async () => {
      await scholarship.disable();
      await expect(scholarship.connect(alice).lendNFT(nftId, bob.address)).to.be.revertedWith(
        "Scholarship:CONTRACT_DISABLED",
      );
    });

    it("Alice lends nft to bob.", async () => {
      await scholarship.enable();
      await scholarship.connect(alice).lendNFT(nftId, bob.address);
      const { owner, scholar } = await scholarship.info(nftId);
      expect(owner).to.eq(alice.address);
      expect(scholar).to.eq(bob.address);
    });

    describe("After lending", () => {
      it("Transfer scholarship", async () => {
        // Transfer scholarship to vault.
        await scholarship.connect(alice).transferScholar(nftId, vault.address);
        const scholar1 = (await scholarship.info(nftId)).scholar;
        expect(scholar1).to.eq(vault.address);

        // Can't access if he isn't owner of NFT.
        await expect(scholarship.connect(bob).transferScholar(nftId, vault.address)).to.be.revertedWith(
          "Scholarship:NOT_OWNER",
        );
      });

      it("Revoke test", async () => {
        // Revoke NFT from sholar.
        await scholarship.connect(alice).revoke(nftId);
        await expect(scholarship.info(nftId)).to.be.revertedWith("Scholarship:NOT_LENDED");
      });
    });
  });

  describe("Bulk lending NFTs test", () => {
    const nftIds = [0, 1, 2, 3];

    before(async () => {
      // Alice has a rooster.
      expect(await rooster.balanceOf(alice.address)).to.eq(4);
      expect(await rooster.totalSupply()).to.eq(4);

      // Give opertor approval
      await rooster.connect(alice).setApprovalForAll(scholarship.address, true);
    });

    it("It will revert if parameter missmatched.", async () => {
      const misMatchAddresses = Array(5).fill(bob.address);
      await expect(scholarship.connect(alice).bulkLendNFT(nftIds, misMatchAddresses)).to.be.revertedWith(
        "Scholarship:PARAM_MISMATCH",
      );
    });

    it("Alice bulk lends nfts to bob.", async () => {
      const addresses = Array(4).fill(bob.address);
      await scholarship.connect(alice).bulkLendNFT(nftIds, addresses);
      const { owner, scholar } = await scholarship.info(nftIds[0]);
      expect(owner).to.eq(alice.address);
      expect(scholar).to.eq(bob.address);
    });

    it("Bulk transfer scholarship to vault.", async () => {
      const addresses = Array(4).fill(bob.address);
      const newAddresses = addresses.map((address, index) => (index ? address : vault.address));
      await scholarship.connect(alice).bulkTransferScholar(nftIds, newAddresses);
      const scholar1 = (await scholarship.info(nftIds[0])).scholar;
      expect(scholar1).to.eq(vault.address);
    });

    it("Bulk revoke NFT from sholar.", async () => {
      await scholarship.connect(alice).bulkRevoke(nftIds);
      await expect(scholarship.info(nftIds[0])).to.be.revertedWith("Scholarship:NOT_LENDED");
    });
  });
});
