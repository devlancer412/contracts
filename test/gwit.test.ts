import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Ship, toBN } from "../utils";
import { GWITToken, GWITToken__factory } from "../types";
import { BigNumber, ContractTransaction } from "ethers";
import { deployments, network } from "hardhat";
import { parseSpecial } from "../utils/parseSpecial";
import { signERC2612Permit } from "eth-permit";

chai.use(solidity);
const { expect } = chai;
const supply_size = parseSpecial("1bi|18");

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
  await deployments.fixture(["mocks", "gwit", "grp", "gwit_init"]);

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

    gwit = await scaffold.ship.connect(GWITToken__factory);
  });

  it("Should have the right supply size", async () => {
    const res = await gwit.initialSupply();
    await expect(res).to.eq(supply_size);
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

  it("Should permit", async () => {
    const result = await signERC2612Permit(network.provider, gwit.address, user.address, shinji.address, 5);
    await gwit.permit(user.address, shinji.address, 5, result.deadline, result.v, result.r, result.s);

    await expect(await gwit.allowance(user.address, shinji.address)).to.eql(toBN(5));
  });
});
