import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "hardhat-deploy-ethers/dist/src/signers";
import { advanceTimeAndBlock, MacroChain, toBN, toWei } from "../utils";
import { FarmPool, FarmPool__factory, GRP,  GRP__factory,  GWITToken,  GWITToken__factory,} from "../typechain";
import {ClaimsManager, Configuration, SignedClaim} from "../claims_lib/manager";
import { ContractTransaction, Wallet } from "ethers";
import { hardhatArguments } from "hardhat";
import { Console } from "console";

chai.use(solidity);
const { expect } = chai;
const supply_size = 1_000_000_000;

let macrochain: MacroChain;
let grp: GRP;
let gwit: GWITToken;
let farmpool: FarmPool;
let issuer: Wallet = Wallet.createRandom();
let owner: SignerWithAddress;
let wallet: SignerWithAddress;
let client: SignerWithAddress;

let manager: ClaimsManager;

describe("GWIT Deploy Test", () => {
    before(async () => {
        macrochain = await MacroChain.init();
        const { users } = macrochain;
        owner = users[0];
        wallet = users[1];
        client = users[2];
      });
    
    before(async () => {
        const { deployer } = macrochain;
        grp = await deployer<GRP__factory>("GRP", [issuer.address]);
        farmpool = await deployer<FarmPool__factory>("FarmPool", []);
        gwit = await deployer<GWITToken__factory>("GWITToken", [supply_size, grp.address, farmpool.address])
        
        await grp.set_token_addr(gwit.address);
        await farmpool.set_token_addr(gwit.address);
        
        manager = new ClaimsManager({
            IssuerPrivateKey: issuer.privateKey,
            ContractAddress: grp.address,
            DomainName: "GRP",
        })
    
    });
    
    it("Should have the right address", async() => {
        let addr = await grp.token_addr();
        expect(addr).to.eq(gwit.address);

        let addr_fp = await farmpool.token_addr();
        expect(addr_fp).to.eq(gwit.address);
    })

    it("Should allocate the right amount of tokens", async () => {
        let balance = await gwit.balanceOf(grp.address);
        expect(balance).to.eq((supply_size * .46).toFixed());   

        let balance_fp = await gwit.balanceOf(farmpool.address);
        expect(balance_fp).to.eq((supply_size * .1).toFixed());
    });

    it("Should emit new signer", async () => {
        let tx = grp.setSigner(issuer.address);
        await expect(tx).to.emit(grp, "UpdateSigner").withArgs(issuer.address);
    });

    it("Should fail with claimed nonce", async () => {
        const claimData = await manager.generate_claim(client.address, 10);
        claimData.nonce = 0;
        // const claimData = {nonce: 0, target: client.address, amount: 37, signature: {r: "aa", s: "bb", v: 47}}
        await expect(grp.claim(claimData)).to.be.revertedWith("claim already claimed")
    })

    it("__signature_test", async () => {
        await grp.setSigner(issuer.address);
        const claimData = await manager.generate_claim(client.address, 10);
        const tx = await grp.view_Test(claimData);
        console.log("Result Hash", tx);
    })

    it("__erc_signature_test", async () => {
        await grp.setSigner(issuer.address);
        const claimData = await manager.generate_claim(client.address, 10);
        const tx = await grp.view_ercrec(claimData);
        console.log("Expect", issuer.address)
        console.log("Result", tx);
        expect(tx).to.eq(issuer.address);
    })


    it("Should validate claim", async () => {
        await grp.setSigner(issuer.address);

        const tx_amt = 10;
        const claimData = await manager.generate_claim(client.address, 10);
        console.log("Claim", claimData);
        // const tx = await grp.claim(claimData);
        // console.log("claim transaction:", tx.data);
        await expect(grp.claim(claimData)).not.be.revertedWith("invalid signature");

        let balance = await gwit.balanceOf(client.address);
        expect(balance).to.eq(tx_amt);
    })
})