import { ethers, upgrades } from "hardhat";

async function main() {
  const [owner, otherAccount] = await ethers.getSigners();
  const MasterCollection = await ethers.getContractFactory(
    "MasterCollectionV3"
  );
  let master = await upgrades.deployProxy(
    MasterCollection,
    ["0x57317a302F8874527C5D4781993EA56814315B1C"],
    {
      kind: "uups",
      initializer: "initialize",
    }
  );

  await master.deployed();
  console.log(`Deployed at ${master.address}`);

  let name = await master.name();
  console.log("Name: ", name);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
