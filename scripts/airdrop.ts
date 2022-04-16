import * as fs from "fs";
import { ethers } from "hardhat";
import { RoosterEggSale__factory } from "../types";
import { Time } from "../utils";
const csvToObj = require("csv-to-js-parser").csvToObj;

interface List {
  amount: number;
  address: string;
}

const main = async () => {
  const data = fs.readFileSync("./z/list7.csv").toString();
  const description = {
    amount: { type: "number", group: 1 },
    address: { type: "string", group: 2 },
  };
  let lists = csvToObj(data, ",", description) as List[];
  const continueFrom = "0x6c3cb6ea7228d8abd2a2b10a640b2a7c2a94baa2";
  lists = lists.slice(lists.findIndex((i) => i.address === continueFrom));

  const signers = await ethers.getSigners();
  let nonce = await ethers.provider.getTransactionCount(await signers[0].getAddress());

  const addr = "0x412D45fB3f93e28cB90DB8096Ce8ed495f119FB3";
  const egg = RoosterEggSale__factory.connect(addr, signers[0]);

  for (let { amount, address } of lists) {
    address = address.replace(/\s+/g, "");
    const q = Math.floor(amount / 50);
    const m = amount % 50;

    console.log("############");
    console.log("Address:", address);
    console.log("Amount :", amount);
    for (let i = 0; i < q; i++) {
      const tx = await egg.mintEggs(address, 50, { nonce: nonce++ });
      console.log("Tx Hash:", tx.hash);
      await tx.wait();
      await Time.delay(3000);
    }
    if (m > 0) {
      const tx = await egg.mintEggs(address, m, { nonce: nonce++ });
      console.log("Tx Hash:", tx.hash);
      await tx.wait();
      await Time.delay(3000);
    }
  }
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
