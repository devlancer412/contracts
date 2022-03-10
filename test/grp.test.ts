import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Ship } from "../utils";
import { GRP, GRP__factory, GWITToken, GWITToken__factory, MasterChef, MasterChef__factory } from "../types";
import { generate_claim, SignedClaim } from "../utils/claims";
import { BigNumber, Wallet } from "ethers";
import { deployments } from "hardhat";
import { parseSpecial } from "../utils/parseSpecial";

chai.use(solidity);
const { expect } = chai;
const supply_size = parseSpecial("1bi|18");

let ship: Ship;
let grp: GRP;
let gwit: GWITToken;
let farm_pool: MasterChef;

const issuer: Wallet = Wallet.createRandom();
let owner: SignerWithAddress;
let wallet: SignerWithAddress;
let client: SignerWithAddress;

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

    grp = await scaffold.ship.connect(GRP__factory);
    gwit = await scaffold.ship.connect(GWITToken__factory);
    farm_pool = await scaffold.ship.connect(MasterChef__factory);

    await grp.setTokenAddr(gwit.address);
  });

  it("Should have the right supply size", async () => {
    const res = await gwit.initialSupply();
    await expect(res).to.eq(supply_size);
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

    // revert back
    grp.setSigner(owner.address);
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
      claimData = await generate_claim(owner, client.address, tx_amt.toNumber());
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
    const claimData = await generate_claim(owner, client.address, 10);
    claimData.amount = 1000;
    await expect(await grp.validateClaim(claimData)).to.be.false;
  });

  it("Should fail with claimed nonce", async () => {
    const claimData = await generate_claim(owner, client.address, 10);

    await expect(await grp.claim(claimData))
      .to.emit(grp, "Claimed")
      .withArgs(claimData.nonce, claimData.target, claimData.amount);

    const second_tx = await grp.claim(claimData);
    await expect(second_tx).to.not.emit(grp, "Claimed");

    const balance = await gwit.balanceOf(client.address);
    await expect(balance).to.eq(10);
  });
});
