import { Contract, BigNumber } from "ethers";
import { arrayify, Interface, solidityKeccak256, splitSignature } from "ethers/lib/utils";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Ship } from "../utils";
import {
  MockUsdc,
  MockUsdc__factory,
  Affiliate,
  Affiliate__factory,
  RoosterEggSale,
  RoosterEggSale__factory,
  RoosterEgg,
  RoosterEgg__factory,
  Store,
  Store__factory,
} from "../types";
import { deployments } from "hardhat";

chai.use(solidity);
const { expect } = chai;

let ship: Ship;
let usdc: MockUsdc;
let affiliate: Affiliate;
let eggSale: RoosterEggSale;
let store: Store;
let egg: RoosterEgg;
let signer: SignerWithAddress;
let alice: SignerWithAddress;
let bob: SignerWithAddress;
let vault: SignerWithAddress;
let deployer: SignerWithAddress;

const setup = deployments.createFixture(async (hre) => {
  const ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture([
    "mocks",
    "eggsale",
    "egg",
    // "grp",
    // "gwit",
    // "marketplace",
    // "nfts",
    // "gwit_init",
    // "store",
    "affiliate",
  ]);

  return {
    ship,
    accounts,
    users,
  };
});

const realAbiEgg = [
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "buyEggWithAffiliate",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const abiEgg = [
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "implementTo",
        type: "address",
      },
      {
        internalType: "address",
        name: "affiliate",
        type: "address",
      },
      {
        internalType: "uint32",
        name: "selector",
        type: "uint32",
      },
    ],
    name: "buyEggWithAffiliate",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const realAbiStore = [
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "listingId",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "buyItemWithAffiliate",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const abiStore = [
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "listingId",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "implementTo",
        type: "address",
      },
      {
        internalType: "address",
        name: "affiliate",
        type: "address",
      },
      {
        internalType: "uint32",
        name: "selector",
        type: "uint32",
      },
    ],
    name: "buyItemWithAffiliate",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const sign = async (sender: string, to: string, redeem_codes: number[], value: number) => {
  const hash = solidityKeccak256(
    ["address", "address", "uint64[]", "uint256"],
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

describe("Affiliate test", () => {
  before(async () => {
    const scaffold = await setup();

    ship = scaffold.ship;
    usdc = await ship.connect(MockUsdc__factory);
    affiliate = await ship.connect(Affiliate__factory);
    eggSale = await ship.connect(RoosterEggSale__factory);
    // store = await ship.connect(Store__factory);
    egg = await ship.connect(RoosterEgg__factory);

    bob = scaffold.accounts.bob;
    alice = scaffold.accounts.alice;
    signer = scaffold.accounts.signer;
    vault = scaffold.accounts.vault;
    deployer = scaffold.accounts.deployer;

    await usdc.mint(signer.address, 100000);
    await affiliate.grantRole("DISTRIBUTOR", signer.address);
    await usdc.connect(signer).approve(affiliate.address, 10000);
  });

  it("alice call reward", async () => {
    const codes = [0, 1, 2, 3];
    const value = 650;

    const aliceAmount = await usdc.balanceOf(alice.address);

    const signature = await sign(signer.address, alice.address, codes, value);
    await affiliate.connect(signer).redeemCode(alice.address, codes, value, signature);

    expect(await usdc.balanceOf(alice.address)).to.eq(aliceAmount.add(650));
  });

  it("alice can't redeem again with same code", async () => {
    const codes = [0, 1, 2, 3];
    const value = 650;

    const signature = await sign(signer.address, alice.address, codes, value);
    await expect(
      affiliate.connect(signer).redeemCode(alice.address, codes, value, signature),
    ).to.be.revertedWith("Affiliate:ALREADY_REDEEMED");
  });

  it("Eggsale test", async () => {
    await eggSale.setAffiliateData(affiliate.address, 50);
    const aliceUsdcAmount = await usdc.balanceOf(alice.address);
    const aliceEggAmount = await egg.balanceOf(alice.address);
    const distributorUsdcAmount = await usdc.balanceOf(vault.address);

    const proxyContract = new Contract(affiliate.address, abiEgg, ship.provider);
    const iRealFace = new Interface(realAbiEgg);

    await usdc.connect(alice).approve(eggSale.address, 500);
    const tx = await proxyContract.connect(alice).buyEggWithAffiliate(
      alice.address, // to address to send egg
      10, // amount of egg
      eggSale.address, // eggsale contract address
      bob.address, // affiliate address
      iRealFace.getSighash("buyEggWithAffiliate"), // function selector to replace
    );
    await tx.wait();

    const proxyEvent = await proxyContract.provider.getLogs({ address: affiliate.address });

    expect(proxyEvent.length).to.eq(1);
    expect(BigNumber.from(proxyEvent[0].data)).to.eq(BigNumber.from(10));
    expect(BigNumber.from(proxyEvent[0].topics[1])).to.eq(BigNumber.from(bob.address));

    expect(await usdc.balanceOf(alice.address)).to.eq(aliceUsdcAmount.sub(500));
    expect(await usdc.balanceOf(vault.address)).to.eq(distributorUsdcAmount.add(500));
    expect(await egg.balanceOf(alice.address)).to.eq(aliceEggAmount.add(10));
  });
  /*
  describe("Store test", () => {
    let listingId: number;
    before(async () => {
      await store.setAffiliateAddress(affiliate.address);
    });

    it("Add list to store", async () => {
      const tokenType = 3; // ERC721EX
      const tokenAddress = egg.address;
      const tokenId = 0; // Only for ERC1155 use
      const amount = 1; // Only mint 1 rooster
      const price = 500; // each mint costs 100 of the operating token
      const maxval = 10; // the maximum value to pass to the unique parameter, leave to 0 to send a random uint256 value [0x00_00...00, 0xFF_FF...FF];
      const rx = await (
        await store.connect(bob).makeListing(tokenType, tokenAddress, tokenId, amount, price, maxval)
      ).wait();

      const ev = rx.events?.find((event) => event.event === "Listed");
      listingId = ev?.args?.listingId;
      await expect(listingId).to.not.eql(-1);
    });

    it("Store test", async () => {
      const aliceUsdcAmount = await usdc.balanceOf(alice.address);
      const aliceItemAmount = await egg.balanceOf(alice.address);
      const distributorUsdcAmount = await usdc.balanceOf(vault.address);

      const proxyContract = new Contract(affiliate.address, abiStore, ship.provider);
      const iRealFace = new Interface(realAbiStore);

      await usdc.connect(alice).approve(eggSale.address, 500);
      const tx = await proxyContract.connect(alice).buyItemWithAffiliate(
        alice.address, // to address to send egg
        1, // amount of egg
        store.address, // eggsale contract address
        bob.address, // affiliate address
        iRealFace.getSighash("buyItemWithAffiliate"), // function selector to replace
      );
      await tx.wait();

      const proxyEvent = await proxyContract.provider.getLogs({ address: affiliate.address });

      expect(proxyEvent.length).to.eq(1);
      expect(BigNumber.from(proxyEvent[0].data)).to.eq(BigNumber.from(1));
      expect(BigNumber.from(proxyEvent[0].topics[1])).to.eq(BigNumber.from(bob.address));

      expect(await usdc.balanceOf(alice.address)).to.eq(aliceUsdcAmount.sub(500));
      expect(await usdc.balanceOf(vault.address)).to.eq(distributorUsdcAmount.add(500));
      expect(await egg.balanceOf(alice.address)).to.eq(aliceItemAmount.add(1));
    });
  });*/
});
