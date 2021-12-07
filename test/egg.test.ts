import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "hardhat-deploy-ethers/dist/src/signers";
import { advanceTimeAndBlock, MacroChain, toBN, toWei } from "../utils";
import { RoosterEgg, RoosterEgg__factory, USDC, USDC__factory } from "../typechain";
import { ethers } from "hardhat";

chai.use(solidity);
const { expect } = chai;

let macrochain: MacroChain;
let egg: RoosterEgg;
let usdc: USDC;
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

    //Deploy USDC
    usdc = await deployer<USDC__factory>("USDC", []);

    //Deploy RoosterEgg
    const uri = "https://api.roosterwars.io/metadata/egg/";
    const initialTokenId = 1;
    egg = await deployer<RoosterEgg__factory>("RoosterEgg", [usdc.address, wallet.address, initialTokenId, uri]);

    const balance = await usdc.balanceOf(owner.address);
    await usdc.transfer(alice.address, balance.div(4));
    await usdc.transfer(bob.address, balance.div(4));
  });

  describe("Presale test", () => {
    before(async () => {
      const currentTime = await egg.getTime();
      const openingTime = currentTime + 1000;
      const closingTime = currentTime + 3000;
      const supply = 150_000;
      const cap = 10;
      const price = toWei(30, 6); //$30
      const cashbackPerEgg = toWei(0.045); //0.045 MATIC

      await egg.setPresale(openingTime, closingTime, supply, cap, price, cashbackPerEgg);
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

      it("Funds matic", async () => {
        const promi = owner.sendTransaction({
          to: egg.address,
          value: toWei(100),
        });
        await expect(promi).to.emit(egg, "MaticReceived").withArgs(owner.address, toWei(100));
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

        await expect(await promi).to.changeEtherBalance(alice, toWei(0.045).mul(amount));
        expect(await egg.balanceOf(alice.address)).to.eq(amount);
      });

      it("Should be able to handle large order", async () => {
        const amount = 9;
        const price = toWei(30, 6);
        const value = toBN(amount).mul(price);

        await usdc.connect(bob).approve(egg.address, value);
        const promi = egg.connect(bob).buyEggs(amount);

        await expect(promi).to.emit(egg, "Purchase").withArgs(bob.address, amount, value);
        expect(await egg.balanceOf(bob.address)).to.eq(9);
      });

      it("Withdraws matic", async () => {
        const eggMaticBalance = await ethers.provider.getBalance(egg.address);
        const walletMaticBalanceBefore = await ethers.provider.getBalance(wallet.address);
        const promi1 = egg.connect(alice).withdrawMatic(eggMaticBalance);
        const promi2 = egg.withdrawMatic(eggMaticBalance);
        
        await expect(promi1).to.be.revertedWith("Invalid access");
        await expect(promi2).to.emit(egg, "MaticWithdrawn").withArgs(eggMaticBalance);

        const walletMaticBalanceAfter = await ethers.provider.getBalance(wallet.address);
        expect(walletMaticBalanceAfter.sub(walletMaticBalanceBefore)).to.eq(eggMaticBalance);
      });

      it("Shouldn't fail even if cashback fails", async () => {
        const amount = 1;
        const price = toWei(30, 6);
        const value = toBN(amount).mul(price);

        await usdc.connect(bob).approve(egg.address, value);
        const promi = egg.connect(bob).buyEggs(amount);

        await expect(promi).to.emit(egg, "MaticCashbackFailed").withArgs(bob.address, 0);
        expect(await egg.balanceOf(bob.address)).to.eq(10);
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
      const promi = egg.connect(rooster).burn(1);
      await expect(promi).to.be.revertedWith("ERC721Burnable: caller is not owner nor approved");
    });

    it("Should allow to burn after approval", async () => {
      await egg.connect(alice).setApprovalForAll(rooster.address, true);
      const promi = egg.connect(rooster).burn(1);

      await expect(promi).not.to.be.reverted;
      expect(await egg.balanceOf(alice.address)).to.eq(1);
    });

    it("Should be able to handle batch burn", async () => {
      await egg.connect(bob).setApprovalForAll(rooster.address, true);
      const ids = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
      const promi = egg.connect(rooster).burnBatch(ids);

      await expect(promi).not.to.be.reverted;
      expect(await egg.balanceOf(bob.address)).to.eq(0);
    });
  });
});
