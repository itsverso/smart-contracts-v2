import { ethers, upgrades } from "hardhat";

async function main() {
	const [owner] = await ethers.getSigners();

	//////////////////////////////////////
    //// Collection Implementation
    /////////////////////////////////////
    const CollectionImplementation = await ethers.getContractFactory("Collection");
	// Deploy proxy
	let collectionImplementation = await CollectionImplementation.deploy();
	// Await
	await collectionImplementation.deployed();
	console.log(`Collection implementation deployed at: ${collectionImplementation.address}`)
  
	//////////////////////////////////////
	//// Collection Factory
	/////////////////////////////////////
  
	const CollectionFactory = await ethers.getContractFactory("CollectionFactory");
	  // Deploy proxy
	let collectionFactory = await CollectionFactory.deploy(
		collectionImplementation.address,
		owner.address
	);
	// Await
	await collectionFactory.deployed();
	console.log(`Collection FACTORY deployed at: ${collectionFactory.address}`)

	//////////////////////////////////////
	//// Collection Registry
	/////////////////////////////////////
  
	const CollectionRegistry = await ethers.getContractFactory(
		"CollectionRegistry"
	);
	// Deploy proxy
	let collectionRegistry = await upgrades.deployProxy(
		CollectionRegistry,
		[owner.address, collectionFactory.address],
		{
		  kind: "uups",
		  initializer: "initialize",
		}
	);
	// Await
	await collectionRegistry.deployed();
	console.log(`Collection REGISTRY deployed at: ${collectionRegistry.address}`)
	const currentImplAddress2 = await upgrades.erc1967.getImplementationAddress(
		collectionRegistry.address
	);
	console.log(`Collection FACTORY - implementation address at: ${currentImplAddress2}`)

	// Set collection registry address on Factory contract
	await collectionFactory.setCollectionRegistryAddress(
		collectionRegistry.address
	);
	console.log('Registry set on Factory')
}

// Sepolia Proxy Address: 0x33F67739DE6c7d12e87514d0A0673129400ea216
// Sepolia Implementation Address: 0x081fd5eDD05da93e9887F510847449EE7d2E1D1F

// Goerli Collection Implementation = 0xb5DD22115F678d8d4048CF04AdaE2cE9fe546382
// Goerli Collection FACTORY = 0x7009e374397e90762cE2Ff1CaB77164d4aA8dFdb
// Goerli Collection REGISTRY = 0xE188943EEd8FE7270F582a52C9a7b46C895cE829
// Goerli Collection registry implementation = 0x26c5197100C2C0189A47a0d0731fFDBfAbfD0cB7



main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
