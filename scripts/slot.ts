import hre from "hardhat";

async function main() {
  await hre.storageLayout.export();
}

main();
