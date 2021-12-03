import chai from "chai";
import hre, { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "hardhat-deploy-ethers/dist/src/signers";
import { advanceTimeAndBlock, MacroChain, toBN, toWei } from "../utils";
import { IERC20, IERC20__factory ,RoosterEgg, RoosterEgg__factory } from "../typechain";

chai.use(solidity);
const { expect } = chai;

let macrochain: MacroChain;
let egg: RoosterEgg;
let usdc: IERC20;
let owner: SignerWithAddress;
let wallet: SignerWithAddress;
let rooster: SignerWithAddress;
let alice: SignerWithAddress;
let bob: SignerWithAddress;
let charlie: SignerWithAddress;

describe("Egg test", () => {
  before(async () => {
    macrochain = await MacroChain.init();
    const { users } = macrochain;
    owner = users[0];
    wallet = users[1];
    rooster = users[2];
    alice = users[3];
    bob = users[4];
    charlie = users[5];
  });

  before(async () => {
    const { deployer } = macrochain;

    //Deploy RoosterEgg
    const usdcAddr = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
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
    usdc = IERC20__factory.connect(usdcAddr, whale);
    const balance = await usdc.balanceOf(whaleAddr);
    await usdc.transfer(owner.address, balance.div(4));
    await usdc.transfer(alice.address, balance.div(4));
    await usdc.transfer(bob.address, balance.div(4));
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
        await usdc.connect(alice).approve(egg.address, value);
        const promi = egg.connect(alice).buyEggs(amount);

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

        await usdc.connect(alice).approve(egg.address, value);
        const promi = egg.connect(alice).buyEggs(amount);

        await expect(promi).not.to.be.reverted;
        
        let total = toBN(0);
        for(let i = 0; i < 9; i++){
          total = (await egg.balanceOf(alice.address, i)).add(total);
        }
        expect(total).to.eq(amount);
      });

      it("Should be able to handle large order", async () => {
        const amount = 10;
        const price = toWei(30, 6);
        const value = toBN(amount).mul(price);

        await usdc.connect(bob).approve(egg.address, value);
        const promi = egg.connect(bob).buyEggs(amount);

        await expect(promi).not.to.be.reverted;
        for(let i = 0; i < 9; i++){
          expect(await egg.balanceOf(bob.address, i)).to.eq(1);
        }
      });

      it("Should fail without sufficient balance", async () => {
        const amount = 1;
        const price = toWei(30, 6);
        const value = toBN(amount).mul(price);

        await usdc.connect(charlie).approve(egg.address, value);
        const promi = egg.connect(charlie).buyEggs(amount);

        await expect(promi).to.be.reverted;
      });

      it("Should fail if it exceeds cap", async () => {
        const amount = 9;
        const price = toWei(30, 6);
        const value = toBN(amount).mul(price);

        await usdc.connect(alice).approve(egg.address, value);
        const promi = egg.connect(alice).buyEggs(amount);

        await expect(promi).to.be.revertedWith("Exceeds cap");
      });
    });

    describe("After presale", () => {
      before(async () => {
        await advanceTimeAndBlock(1500);
      });

      it("Should return not open", async () => {
        expect(await egg.isOpen()).to.be.false;
      });

      it("Shouldn't allow users to buy", async () => {
        const amount = 2;
        const price = toWei(30, 6);
        const value = toBN(amount).mul(price);
        await usdc.connect(alice).approve(egg.address, value);
        const promi = egg.connect(alice).buyEggs(amount);

        await expect(promi).to.be.revertedWith("Not open");
      });
    });
  });

  describe("Burn test", () => {
    it("Should fail to burn without approval", async () => {
      const promi = egg.connect(rooster).burn(alice.address, 0, 1);
      await expect(promi).to.be.revertedWith("ERC1155: caller is not owner nor approved");
    });

    it("Should allow to burn after approval", async () => {
      let id = 0;
      for(let i = 0; i < 9; i++){
        if((await egg.balanceOf(alice.address, i)).toString() === "1"){
          id = i;
          break;
        }
      }

      await egg.connect(alice).setApprovalForAll(rooster.address, true);
      const promi = egg.connect(rooster).burn(alice.address, id, 1);

      await expect(promi).not.to.be.reverted;
      expect(await egg.balanceOf(alice.address, 0)).to.eq(0);
    });

    it("Should be able to handle batch burn", async () => {
      await egg.connect(bob).setApprovalForAll(rooster.address, true);
      const values = new Array(10).fill(1);
      const ids = values.map((_, i) => i);
      const promi = egg.connect(rooster).burnBatch(bob.address, ids, values);

      await expect(promi).not.to.be.reverted;
      for(let i = 0; i < 9; i++){
        expect(await egg.balanceOf(bob.address, i)).to.eq(0);
      }
    });
  })
});
