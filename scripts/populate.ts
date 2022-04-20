import { BigNumber, ContractReceipt } from "ethers";
import * as fs from "fs";
import { deployments, ethers } from "hardhat";
import { GWITToken__factory, Marketplace__factory, Rooster__factory } from "../types";
import { Ship, Time } from "../utils";
const csvToObj = require("csv-to-js-parser").csvToObj;

interface List {
  amount: number;
  address: string;
}

const main = async () => {
  const setup = deployments.createFixture(async (hre) => {
    const ship = await Ship.init(hre);
    const { accounts, users } = ship;
    await deployments.fixture(["mocks", "grp", "gwit", "marketplace", "nfts", "gwit_init"]);

    return {
      ship,
      accounts,
      users,
    };
  });

  const getId = (rx: ContractReceipt) => {
    const events = rx.events ?? [];
    for (const ev of events) {
      if (ev.event === "Transfer" && ev.args?.to === seller.address) {
        return ev.args.id;
      }
    }
  };

  const scaffold = await setup();
  const seller = scaffold.users[0];

  const marketplace = await scaffold.ship.connect(Marketplace__factory);
  const gwit = await scaffold.ship.connect(GWITToken__factory);
  const rooster = await scaffold.ship.connect(Rooster__factory);
  console.log("Marketplace Address", marketplace.address);

  await rooster.grantMinterRole(seller.address);
  await gwit.transfer(seller.address, 10_000_000);
  await marketplace.setAllowedToken(rooster.address, true);

  for (let i = 0; i < 10; i++) {
    const rx: ContractReceipt = await (await rooster.connect(seller).mint(seller.address, 0)).wait();
    let nftId: BigNumber = getId(rx);
    console.log("Minting", nftId.toString());
    await rooster.connect(seller).approve(marketplace.address, nftId);
    await marketplace.connect(seller).makeListing(rooster.address, nftId, 1, 1400, false);
    console.log("Listing", nftId.toString());
  }
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
