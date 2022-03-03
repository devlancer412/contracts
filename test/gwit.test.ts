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

        let balance_caller = await gwit.balanceOf(owner.address);
        expect(balance_caller).to.eq((supply_size * .44).toFixed());
        
    });

    it("Should emit new signer", async () => {
        let tx = grp.setSigner(issuer.address);
        await expect(tx).to.emit(grp, "UpdateSigner").withArgs(issuer.address);
    });

    it("Should fail with invalid signature", async () => {
        const claimData = await manager.generate_claim(client.address, 10);
        claimData.amount = 1000;
        await expect(grp.claim(claimData)).to.be.revertedWith("invalid signature")
    });

    it("Should fail with claimed nonce", async () => {
        const claimData = await manager.generate_claim(client.address, 10);

        await expect(grp.claim(claimData)).to.emit(grp, "Claimed").withArgs(claimData.nonce, claimData.target, claimData.amount);
        
        const second_tx = grp.claim(claimData)
        expect(second_tx).to.be.revertedWith("claim already claimed")

        let balance = await gwit.balanceOf(client.address);
        expect(balance).to.eq(10); 
    });

    it("Should validate claim", async () => {
        const reserves = await grp.reserves();
        const original = await gwit.balanceOf(client.address);
        const tx_amt = 10;
        const claimData = await manager.generate_claim(client.address, tx_amt);
        await expect(grp.claim(claimData)).not.be.revertedWith("invalid signature");

        let balance = await gwit.balanceOf(client.address);
        expect(balance).to.eq(original.add(tx_amt));
        
        let new_reserves = await grp.reserves();
        expect(new_reserves).to.eq(reserves.sub(tx_amt));
    });
})