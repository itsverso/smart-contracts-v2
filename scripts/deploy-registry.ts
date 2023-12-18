import { ethers, upgrades } from "hardhat";
import PROFILE_ABI from "../artifacts/contracts/NewProfileRegistry.sol/ProfileRegistry.json";

async function main() {
	// Private key
	const privateKey = process.env.PRIVATE_KEY as string;
	// Alchemy API key
	const alchemyKey = process.env.ALCHEMY_KEY;
	// Instantiate provider
	const Provider = new ethers.providers.AlchemyProvider(
		"optimism-goerli",
		alchemyKey
	);
	// Create a signer with the specified private key
	const signer = new ethers.Wallet(privateKey, Provider);
	// Instantiate contract with signer
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

	console.log(`Deployed at ${registry.address}`);
	console.log(`Implementation at: ${currentImplAddress}`);

	let instance = new ethers.Contract(registry.address, PROFILE_ABI.abi);

	let owner = await instance.owner();
	console.log("Owner: ", owner);
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
