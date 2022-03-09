import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { advanceTimeAndBlock, Ship, toBN, toWei } from "../utils";
import { GRP, GRP__factory, GWITToken, GWITToken__factory, MasterChef, MasterChef__factory } from "../types";
import { ClaimsManager, Configuration, SignedClaim } from "../claims_lib/manager";
import { BigNumber, ContractTransaction, Wallet } from "ethers";
import { deployments, hardhatArguments } from "hardhat";
import { Console } from "console";

chai.use(solidity);
const { expect } = chai;
let supply_size = BigNumber.from("1_000_000_000_000".replaceAll("_", ""));

let ship: Ship;
let grp: GRP;
let gwit: GWITToken;
let farm_pool: MasterChef;

const issuer: Wallet = Wallet.createRandom();
let owner: SignerWithAddress;
let wallet: SignerWithAddress;
let client: SignerWithAddress;

let manager: ClaimsManager;

const setup = deployments.createFixture(async (hre) => {
  const ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["mocks", "gwit", "grp"]);

  return {
    ship,
    accounts,
    users,
  };
});

describe("GRP test", () => {
  before(async () => {
    const scaffold = await setup();
    owner = scaffold.users[0];
    wallet = scaffold.users[1];
    client = scaffold.users[2];

    grp = await scaffold.ship.deploy(GRP__factory, {
      args: [owner.address],
    });

    gwit = await scaffold.ship.deploy(GWITToken__factory, {
      args: [supply_size],
    });

    await grp.setTokenAddr(gwit.address);

    const startBlock = 10;
    const gwitPerBlock = BigNumber.from("100" + "000000000000000000");
    const bonusEndBlock = startBlock + 100;
    farm_pool = await scaffold.ship.deploy(MasterChef__factory, {
      args: [gwit.address, owner.address, gwitPerBlock, bonusEndBlock, startBlock],
    });

    manager = new ClaimsManager({
      IssuerPrivateKey: issuer.privateKey,
      ContractAddress: grp.address,
    });

    supply_size = BigNumber.from("1000000000000000000000000000000");
  });

  it("Should have the right supply size", async () => {
    const res = await gwit.initialSupply();
    await expect(res).to.eq(BigNumber.from("1000000000000000000000000000000"));
  });

  it("Should initialize", async () => {
    const tx = await gwit.init(grp.address, farm_pool.address);
    console.log(tx.raw);
    await expect(tx).to.emit(gwit, "Initialized");
  });

  it("Should have the right address", async () => {
    const addr = await grp.tokenAddr();
    await expect(addr).to.eq(gwit.address);
  });

  it("Should allocate the right amount of tokens", async () => {
    const balance = await gwit.balanceOf(grp.address);
    await expect(balance).to.eq(supply_size.mul(46).div(100));
  });

  it("Should emit new signer", async () => {
    const tx = grp.setSigner(issuer.address);
    await expect(tx).to.emit(grp, "UpdateSigner").withArgs(issuer.address);
  });

  describe("Validate and Process claim", async () => {
    let original: BigNumber;
    let claimData: SignedClaim;
    let tx_amt: BigNumber;
    let reserves: BigNumber;

    before(async () => {
      reserves = await grp.reserves();
      original = await gwit.balanceOf(client.address);
      tx_amt = BigNumber.from(10);
      claimData = await manager.generate_claim(client.address, tx_amt.toNumber());
    });

    it("Should successfully claim", async () => {
      await expect(await grp.claim(claimData))
        .to.emit(grp, "Claimed")
        .withArgs(claimData.nonce, claimData.target, claimData.amount);
    });

    it("Should credit the claim to the client", async () => {
      const balance = await gwit.balanceOf(client.address);
      await expect(balance).to.eq(original.add(tx_amt));
    });

    it("Should subtract the balance from the reserves", async () => {
      const new_reserves = await grp.reserves();
      await expect(new_reserves).to.eq(reserves.sub(tx_amt));
    });

    after(async () => {
      // return the tokens back to the GRP
      await gwit.connect(client).transfer(grp.address, 10);
    });
  });

  it("Should fail with invalid signature", async () => {
    const claimData = await manager.generate_claim(client.address, 10);
    claimData.amount = 1000;
    await expect(await grp.validateClaim(claimData)).to.be.false;
  });

  it("Should fail with claimed nonce", async () => {
    const claimData = await manager.generate_claim(client.address, 10);

    await expect(grp.claim(claimData))
      .to.emit(grp, "Claimed")
      .withArgs(claimData.nonce, claimData.target, claimData.amount);

    const second_tx = grp.claim(claimData);
    expect(second_tx).to.not.emit(grp, "Claimed");

    const balance = await gwit.balanceOf(client.address);
    expect(balance).to.eq(10);
  });
});
