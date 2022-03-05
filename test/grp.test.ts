import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { advanceTimeAndBlock, Ship, toBN, toWei } from "../utils";
import { GRP, GRP__factory, GWITToken, GWITToken__factory } from "../types";
import { ClaimsManager, Configuration, SignedClaim } from "../claims_lib/manager";
import { ContractTransaction, Wallet } from "ethers";
import { deployments, hardhatArguments } from "hardhat";
import { Console } from "console";

chai.use(solidity);
const { expect } = chai;
const supply_size = 1_000_000_000;

let ship: Ship;
let grp: GRP;
let gwit: GWITToken;
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

describe("GWIT Deploy Test", () => {
  before(async () => {
    const scaffold = await setup();
    owner = scaffold.users[0];
    wallet = scaffold.users[1];
    client = scaffold.users[2];

    grp = await scaffold.ship.deploy(GRP__factory, { args: [issuer.address] });
    gwit = await scaffold.ship.deploy(GWITToken__factory, {
      args: [supply_size, grp.address],
    });

    await grp.setTokenAddr(gwit.address);

    manager = new ClaimsManager({
      IssuerPrivateKey: issuer.privateKey,
      ContractAddress: grp.address,
    });
  });

  it("Should have the right address", async () => {
    const addr = await grp.tokenAddr();
    expect(addr).to.eq(gwit.address);
  });

  it("Should allocate the right amount of tokens", async () => {
    const balance = await gwit.balanceOf(grp.address);
    expect(balance).to.eq((supply_size * 0.46).toFixed());
  });

  it("Should emit new signer", async () => {
    const tx = grp.setSigner(issuer.address);
    await expect(tx).to.emit(grp, "UpdateSigner").withArgs(issuer.address);
  });

  it("Should validate claim", async () => {
    const reserves = await grp.reserves();
    const original = await gwit.balanceOf(client.address);
    const tx_amt = 10;
    const claimData = await manager.generate_claim(client.address, tx_amt);
    await expect(await grp.claim(claimData))
      .to.emit(grp, "Claimed")
      .withArgs(claimData.nonce, claimData.target, claimData.amount);

    const balance = await gwit.balanceOf(client.address);
    await expect(balance).to.eq(original.add(tx_amt));

    const new_reserves = await grp.reserves();
    await expect(new_reserves).to.eq(reserves.sub(tx_amt));

    // return the tokens back to the GRP
    await gwit.connect(client).transfer(grp.address, 10);
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
