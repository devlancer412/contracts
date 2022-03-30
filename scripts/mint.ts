import * as fs from "fs";
import { ethers } from "hardhat";
import { RoosterEgg__factory } from "../types";
import { Time } from "../utils";
const csvToObj = require("csv-to-js-parser").csvToObj;

interface List {
  amount: number;
  address: string;
}

const main = async () => {
  const data = fs.readFileSync("./z/list4.csv").toString();
  const description = {
    amount: { type: "number", group: 1 },
    address: { type: "string", group: 2 },
  };
  let lists = csvToObj(data, ",", description) as List[];
  const continueFrom = "0x3FC213a2EeAf831FF2B321ae85cB73Ba6A2E8E0E";
  lists = lists.slice(lists.findIndex((i) => i.address === continueFrom));

  const signers = await ethers.getSigners();
  let nonce = await ethers.provider.getTransactionCount(await signers[0].getAddress());

  const addr = "0xbDD4AE46B65977a1d06b365c09B4e0F429c70Aef";
  const egg = RoosterEgg__factory.connect(addr, signers[0]);

  for (const { amount, address } of lists) {
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
