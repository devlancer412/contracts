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
    await scholarship.enable();
    await rooster.connect(alice).mint(alice.address, 0);
    await rooster.connect(alice).mint(alice.address, 0);
    await rooster.connect(alice).mint(alice.address, 0);
    await rooster.connect(alice).mint(alice.address, 0);
  });

  it("Lending a NFT test", async () => {
    // Alice has a rooster.
    expect(await rooster.balanceOf(alice.address)).to.eq(4);
    expect(await rooster.totalSupply()).to.eq(4);

    const nftId = 0;
    expect(await rooster.ownerOf(nftId)).to.eq(alice.address);
    // Give opertor approval
    await rooster.connect(alice).setApprovalForAll(scholarship.address, true);

    // Alice lends nft to bob.
    await scholarship.connect(alice).lendNFT(nftId, bob.address);
    const { owner, scholar } = await scholarship.info(nftId);
    expect(owner).to.eq(alice.address);
    expect(scholar).to.eq(bob.address);

    // Transfer scholarship to vault.
    await scholarship.connect(alice).transferScholar(nftId, vault.address);
    const scholar1 = (await scholarship.info(nftId)).scholar;
    expect(scholar1).to.eq(vault.address);

    // Revoke NFT from sholar.
    await scholarship.connect(alice).revoke(nftId);
    await expect(scholarship.info(nftId)).to.be.revertedWith("Scholarship:NOT_LENDED");
  });

  it("Bulk lending NFTs test", async () => {
    // Alice has a rooster.
    expect(await rooster.balanceOf(alice.address)).to.eq(4);
    expect(await rooster.totalSupply()).to.eq(4);

    const nftIds = [0, 1, 2, 3];
    const addresses = Array(4).fill(bob.address);
    // Give opertor approval
    await rooster.connect(alice).setApprovalForAll(scholarship.address, true);

    // Alice lends nft to bob.
    await scholarship.connect(alice).bulkLendNFT(nftIds, addresses);
    const { owner, scholar } = await scholarship.info(nftIds[0]);
    expect(owner).to.eq(alice.address);
    expect(scholar).to.eq(bob.address);

    // Transfer scholarship to vault.
    const newAddresses = addresses.map((address, index) => (index ? address : vault.address));
    await scholarship.connect(alice).bulkTransferScholar(nftIds, newAddresses);
    const scholar1 = (await scholarship.info(nftIds[0])).scholar;
    expect(scholar1).to.eq(vault.address);

    // Revoke NFT from sholar.
    await scholarship.connect(alice).bulkRevoke(nftIds);
    await expect(scholarship.info(nftIds[0])).to.be.revertedWith("Scholarship:NOT_LENDED");
  });
});
