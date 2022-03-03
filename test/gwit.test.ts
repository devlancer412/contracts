import chai from "chai";
import { solidity } from "ethereum-waffle";
import { SignerWithAddress } from "hardhat-deploy-ethers/dist/src/signers";
import { advanceTimeAndBlock, MacroChain, toBN, toWei } from "../utils";
import { FarmPool, FarmPool__factory, GRP,  GRP__factory,  GWITToken,  GWITToken__factory,  RoosterEgg, RoosterEgg__factory, USDC, USDC__factory } from "../typechain";
import { ethers } from "hardhat";

chai.use(solidity);
const { expect } = chai;
const supply_size = 1_000_000_000;

let macrochain: MacroChain;
let grp: GRP;
let gwit: GWITToken;
let farmpool: FarmPool;
let owner: SignerWithAddress;
let wallet: SignerWithAddress;


describe("GWIT Deploy Test", () => {
    before(async () => {
        macrochain = await MacroChain.init();
        const { users } = macrochain;
        owner = users[0];
        wallet = users[1];
      });
    
    before(async () => {
        const { deployer } = macrochain;
        grp = await deployer<GRP__factory>("GRP", []);
        farmpool = await deployer<FarmPool__factory>("FarmPool", []);
        gwit = await deployer<GWITToken__factory>("GWITToken", [supply_size, grp.address, farmpool.address])
        
        await grp.set_token_addr(gwit.address);
        await farmpool.set_token_addr(gwit.address);
    
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
})