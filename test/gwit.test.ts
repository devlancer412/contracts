import chai, { use } from "chai";
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
let gwit: GWITToken;

let owner: SignerWithAddress;
let user: SignerWithAddress;
let tax_address: SignerWithAddress;
let taxed_destination: SignerWithAddress;
let shinji: SignerWithAddress;

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
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
    user = scaffold.users[1];
    tax_address = scaffold.users[2];
    taxed_destination = scaffold.users[3];
    shinji = scaffold.users[4];

    gwit = await scaffold.ship.deploy(GWITToken__factory, {
      args: [supply_size],
    });

    await gwit.init(
      "0x0000000000000000000000000000000000001337",
      "0x0000000000000000000000000000000000001337",
    );

    supply_size = BigNumber.from("1000000000000000000000000000000");
  });

  it("Should have the right supply size", async () => {
    const res = await gwit.initialSupply();
    await expect(res).to.eq(BigNumber.from("1000000000000000000000000000000"));
  });

  it("Should transfer tokens", async () => {
    await gwit.transfer(user.address, 1000);
    await expect(await gwit.balanceOf(user.address)).to.eq(1000);
  });

  it("Should set tax destination", async () => {
    await gwit.setTaxAddress(tax_address.address);
    await expect(await gwit.tax_address()).to.eq(tax_address.address);
  });

  it("Should make an address taxed", async () => {
    await gwit.setTaxRate(taxed_destination.address, 500);
    await expect(await gwit.taxRate(taxed_destination.address)).to.eq(500);
  });

  describe("Taxing", async () => {
    let expectedTax: BigNumber;
    let taxRate: BigNumber;
    let amount: BigNumber;
    let tx: ContractTransaction;

    before(async () => {
      taxRate = BigNumber.from(525);
      amount = BigNumber.from(500);
      expectedTax = taxRate.mul(amount).div(10_000);

      await gwit.setTaxRate(taxed_destination.address, 525);
      await gwit.connect(user).approve(taxed_destination.address, amount);

      tx = await gwit
        .connect(taxed_destination)
        .transferFrom(user.address, taxed_destination.address, amount);
    });

    it("Should calculate tax", async () => {
      const amount = BigNumber.from(1000);
      const tx = await gwit.calcTaxRate(taxed_destination.address, amount);
      await expect(tx).to.eq(taxRate.mul(amount).div(10_000));
    });

    it("Should emit taxed event", async () => {
      await expect(tx).to.emit(gwit, "Taxed").withArgs(user.address, taxed_destination.address, expectedTax);
    });

    it("Should emit transfer event", async () => {
      await expect(tx)
        .to.emit(gwit, "Transfer")
        .withArgs(user.address, taxed_destination.address, amount.sub(expectedTax));
    });

    it("Should send the tax fees to the tax address", async () => {
      await expect(await gwit.balanceOf(tax_address.address)).to.eq(expectedTax);
    });

    it("Should send the deducted amount to the taxed address", async () => {
      await expect(await gwit.balanceOf(taxed_destination.address)).to.eq(amount.sub(expectedTax));
    });
  });

  it("Should transfer on non taxed approve", async () => {
    const amount = 10;
    await gwit.connect(user).approve(shinji.address, amount);
    const tx = await gwit.connect(shinji).transferFrom(user.address, shinji.address, amount);
    await expect(tx).to.emit(gwit, "Transfer").withArgs(user.address, shinji.address, amount);
    await expect(tx).to.not.emit(gwit, "Taxed");
  });
});
