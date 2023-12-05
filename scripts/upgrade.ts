import { ethers, upgrades } from "hardhat";

async function main() {
  // 0xB51552B78F8D086b68fe8E6d5f05B4e0A45A454d -- goerli
  // 0x2E3f57349B8f6BB8859A6E0F647d352ad0D3C8E1 -- mainnet

  const MasterCollection = await ethers.getContractFactory("MasterCollection");
  // 0xB51552B78F8D086b68fe8E6d5f05B4e0A45A454d -- goerli
  // 0x2E3f57349B8f6BB8859A6E0F647d352ad0D3C8E1 -- mainnet

  let master = await upgrades.deployProxy(
    MasterCollection,
    ["0x57317a302F8874527C5D4781993EA56814315B1C"],
    {
      kind: "uups",
      initializer: "initialize",
    }
  );

  await master.deployed();

  // 0x20b89874276CeF0025BE83Aabfb33F88Db3025E9 -- goerli
  // 0x1FBec6824Cf5f485849955714b9470c3B9bE0204 -- mainnet
  const currentImplAddress = await upgrades.erc1967.getImplementationAddress(
    master.address
  );

  console.log(`Deployed at ${master.address}`);
  console.log(`Implementation at: ${currentImplAddress}`);

  const PROXY = master.address;
  const MasterCollectionV2 = await ethers.getContractFactory(
    "MasterCollectionV2"
  );

  console.log("validating");
  await upgrades.validateUpgrade(PROXY, MasterCollectionV2);

  console.log("Preparing ...");
  let newAddress = await upgrades.prepareUpgrade(PROXY, MasterCollectionV2, {
    kind: "uups",
  });
  console.log("Authorizing... ");
  await master.allowUpgradeFor(newAddress);

  console.log("Updating");
  let masterV2 = await upgrades.upgradeProxy(PROXY, MasterCollectionV2, {
    kind: "uups",
  });
  console.log("Master upgraded successfully at: ", masterV2);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
