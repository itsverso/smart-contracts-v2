import { ethers, upgrades } from "hardhat";
import PROFILE_ABI from "../artifacts/contracts/NewProfileRegistry.sol/ProfileRegistry.json";

async function main() {
	const Registry = await ethers.getContractFactory("ProfileRegistry");
	let registry = await upgrades.deployProxy(
		Registry,
		["0x57317a302F8874527C5D4781993EA56814315B1C"],
		{
			kind: "uups",
			initializer: "initialize",
		}
	);

	await registry.deployed();
	const currentImplAddress = await upgrades.erc1967.getImplementationAddress(
		registry.address
	);

	let instance = new ethers.Contract(registry.address, PROFILE_ABI.abi);

	console.log(`Deployed at ${registry.address}`);
	console.log(`Implementation at: ${currentImplAddress}`);

	let tx = await registry.registerProfile(
		"0x57317a302F8874527C5D4781993EA56814315B1C",
		"itsahandle",
		"www.url.com"
	);

	await tx.wait();
	console.log("registered profile?");

	/**
  console.log("validating");
  await upgrades.validateUpgrade(registry.address, Registry);
  console.log("Upgrading ...");
  let masterV2 = await upgrades.upgradeProxy(registry.address, Registry, {
    kind: "uups",
  });
  console.log("Master upgraded successfully at: ", masterV2);
   */
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
