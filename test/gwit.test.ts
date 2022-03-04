import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { advanceTimeAndBlock, Ship, toBN, toWei } from "../utils";
import { FarmPool, FarmPool__factory, GRP, GRP__factory, GWITToken, GWITToken__factory } from "../types";
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
let farmpool: FarmPool;
let issuer: Wallet = Wallet.createRandom();
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
    farmpool = await scaffold.ship.deploy(FarmPool__factory);
    gwit = await scaffold.ship.deploy(GWITToken__factory, {
      args: [supply_size, grp.address, farmpool.address],
    });

    await grp.set_token_addr(gwit.address);
    await farmpool.set_token_addr(gwit.address);

    manager = new ClaimsManager({
      IssuerPrivateKey: issuer.privateKey,
      ContractAddress: grp.address,
    });
  });

  it("Should have the right address", async () => {
    let addr = await grp.token_addr();
    expect(addr).to.eq(gwit.address);

    let addr_fp = await farmpool.token_addr();
    expect(addr_fp).to.eq(gwit.address);
  });

  it("Should allocate the right amount of tokens", async () => {
    let balance = await gwit.balanceOf(grp.address);
    expect(balance).to.eq((supply_size * 0.46).toFixed());

    let balance_fp = await gwit.balanceOf(farmpool.address);
    expect(balance_fp).to.eq((supply_size * 0.1).toFixed());

    let balance_caller = await gwit.balanceOf(owner.address);
    expect(balance_caller).to.eq((supply_size * 0.44).toFixed());
  });

  it("Should emit new signer", async () => {
    let tx = grp.setSigner(issuer.address);
    await expect(tx).to.emit(grp, "UpdateSigner").withArgs(issuer.address);
  });

  it("Should fail with invalid signature", async () => {
    const claimData = await manager.generate_claim(client.address, 10);
    claimData.amount = 1000;
    await expect(grp.claim(claimData)).to.be.revertedWith("invalid signature");
  });

  it("Should fail with claimed nonce", async () => {
    const claimData = await manager.generate_claim(client.address, 10);

    await expect(grp.claim(claimData))
      .to.emit(grp, "Claimed")
      .withArgs(claimData.nonce, claimData.target, claimData.amount);

    const second_tx = grp.claim(claimData);
    expect(second_tx).to.be.revertedWith("claim already claimed");

    let balance = await gwit.balanceOf(client.address);
    expect(balance).to.eq(10);
  });

  it("Should validate claim", async () => {
    const reserves = await grp.reserves();
    const original = await gwit.balanceOf(client.address);
    const tx_amt = 10;
    const claimData = await manager.generate_claim(client.address, tx_amt);
    await expect(grp.claim(claimData))
      .to.emit(grp, "Claimed")
      .withArgs(claimData.nonce, claimData.target, claimData.amount);

    let balance = await gwit.balanceOf(client.address);
    expect(balance).to.eq(original.add(tx_amt));

    let new_reserves = await grp.reserves();
    expect(new_reserves).to.eq(reserves.sub(tx_amt));
  });
});
