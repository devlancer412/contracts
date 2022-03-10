import { Wallet } from "ethers";
import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const issuer: Wallet = Wallet.createRandom();
  const GRP = await ethers.getContractFactory("GRP");
  const grp = await GRP.deploy(issuer.address);

  console.log("Greeter deployed to:", grp.address);
  console.log("Issuer");
  console.log(" -> Mnemonic:", issuer.mnemonic);
  console.log(" -> PK      :", issuer.privateKey);
  console.log(" -> Address :", issuer.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
