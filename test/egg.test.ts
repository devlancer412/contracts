import chai from "chai";
import hre, { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "hardhat-deploy-ethers/dist/src/signers";
import { advanceTimeAndBlock, getCurrentTime, MacroChain, toBN, toWei } from "../utils";
import { IUSDC__factory, RoosterEgg, RoosterEgg__factory } from "../typechain";
import { BigNumber } from "ethers";

chai.use(solidity);
const { expect } = chai;
const { utils, constants } = ethers;

let macrochain: MacroChain;
let egg: RoosterEgg;
let owner: SignerWithAddress;
let wallet: SignerWithAddress;
let alice: SignerWithAddress;
let bob: SignerWithAddress;

const signERC3009Transfer = async (from: SignerWithAddress, to: string, value: BigNumber) => {
  const msg = {
    from: from.address,
    to,
    value: value.toString(),
    validAfter: 0,
    validBefore: Math.floor(Date.now() / 1000) + 3600,
    nonce: utils.hexlify(utils.randomBytes(32)),
  };
  const data = {
    types: {
      EIP712Domain: [
        { name: "name", type: "string" },
        { name: "version", type: "string" },
        { name: "chainId", type: "uint256" },
        { name: "verifyingContract", type: "address" },
      ],
      TransferWithAuthorization: [
        { name: "from", type: "address" },
        { name: "to", type: "address" },
        { name: "value", type: "uint256" },
        { name: "validAfter", type: "uint256" },
        { name: "validBefore", type: "uint256" },
        { name: "nonce", type: "bytes32" },
      ],
    },
    domain: {
      name: "USD Coin (PoS)",
      version: "1",
      chainId: 137,
      verifyingContract: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174"
    },
    primaryType: "TransferWithAuthorization",
    message: msg,
  };
  const rawsig = await from.signMessage(JSON.stringify(data));

  const sig = {
    r: rawsig.slice(0, 66),
    s: "0x" + rawsig.slice(66, 130),
    v: parseInt(rawsig.slice(130, 132), 16),
  };
  
  return {
    msg,
    sig,
  };
};

describe("Egg test", () => {
  before(async () => {
    macrochain = await MacroChain.init();
    const { users } = macrochain;
    owner = users[0];
    wallet = users[1];
    alice = users[2];
    bob = users[3];
  });

  before(async () => {
    const { deployer } = macrochain;

    //Deploy RoosterEgg
    const usdcAddr = "0x2791bca1f2de4661ed88a30c99a7a9449aa84174";
    const uri = "https://api.roosterwars.io/metadata/egg/";
    const varients = 10;
    egg = await deployer<RoosterEgg__factory>("RoosterEgg", [usdcAddr, wallet.address, uri, varients]);

    //Get USDC
    const whaleAddr = "0x986a2fCa9eDa0e06fBf7839B89BfC006eE2a23Dd";
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [whaleAddr],
    });
    const whale = await ethers.getSigner(whaleAddr);
    const usdc = IUSDC__factory.connect(usdcAddr, whale);
    const balance = await usdc.balanceOf(whaleAddr);
    await usdc.transfer(owner.address, balance.div(2));
    await usdc.transfer(alice.address, balance.div(2));
  });

  describe("Presale test", () => {
    before(async () => {
      const currentTime = await egg.getTime();
      const openingTime = currentTime + 1000;
      const closingTime = currentTime + 3000;
      const price = toWei(30, 6); //$30
      const supply = 150_000;
      const cap = 10;

      await egg.setPresale(openingTime, closingTime, price, supply, cap);
    });

    describe("Before presale", () => {
      it("Should return not open", async () => {
        expect(await egg.isOpen()).to.be.false;
      });

      it("Shouldn't allow users to buy", async () => {
        const amount = 2;
        const price = toWei(30, 6);
        const value = toBN(amount).mul(price);
        
        const { msg, sig } = await signERC3009Transfer(alice, wallet.address, value);
        const promi = egg.connect(alice).buyEggs(amount, msg.validAfter, msg.validBefore, msg.nonce, sig.v, sig.r, sig.s);
        
        await expect(promi).to.be.revertedWith("Not open");
      });
    });

    describe("During presale", () => {
      before(async () => {
        await advanceTimeAndBlock(1500);
      });

      it("Should allow users to buy", async () => {
        const amount = 2;
        const price = toWei(30, 6);
        const value = toBN(amount).mul(price);
        
        const { msg, sig } = await signERC3009Transfer(alice, wallet.address, value);
        const promi = egg.connect(alice).buyEggs(amount, msg.validAfter, msg.validBefore, msg.nonce, sig.v, sig.r, sig.s);
        
        // await expect(promi).not.to.be.reverted;
        await promi;
      });
    });
  });
});
