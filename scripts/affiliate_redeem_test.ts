import { splitSignature } from "ethers/lib/utils";
import { arrayify } from "ethers/lib/utils";
import { solidityKeccak256 } from "ethers/lib/utils";
import { expect } from "chai";
import { MockUsdc__factory, RoosterEgg__factory, Affiliate__factory } from "../types";
import { Ship, Time, toWei } from "../utils";

const sign = async (signer: any, sender: string, to: string, redeem_codes: number[], value: number) => {
  const hash = solidityKeccak256(
    ["address", "address", "uint256[]", "uint256"],
    [sender, to, redeem_codes, value],
  );
  const sig = await signer.signMessage(arrayify(hash));
  const { r, s, v } = splitSignature(sig);
  return {
    r,
    s,
    v,
  };
};

const main = async () => {
  const { connect, provider, accounts } = await Ship.init();

  console.log("preparing....");
  const affiliate = await connect(Affiliate__factory);
  const usdc = await connect(MockUsdc__factory);

  const codes = [0, 3];
  const value = 48_000_000;
  const redeemer = "0x1363a979EB9D2054414dfCDD023412f59c9F08cC";

  const realSig = await sign(accounts.signer, redeemer, redeemer, codes, value);

  const signature = {
    r: "0xb744b5de376db1f741f9c58ae2f01a48eb1a2338dfd94cc3fe3302681a1f5e63",
    s: "0x3278ffc54550ceaceb0281fd19bf2ebc01c63f4c762e79b2f2d0998edf3cd655",
    v: 28,
  };

  // console.log(realSig);
  console.log("asking redeem");
  await (await usdc.connect(accounts.vault).approve(affiliate.address, value)).wait();
  await (
    await affiliate
      .connect(accounts.bob)
      .redeemCode(redeemer, codes, value, signature, { gasLimit: "1000000000000000000000" })
  ).wait();
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
