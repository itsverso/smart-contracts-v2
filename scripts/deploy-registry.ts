import { ethers, upgrades } from "hardhat";
import PROFILE_ABI from "../artifacts/contracts/NewProfileRegistry.sol/ProfileRegistry.json";

async function main() {
	let registry;
	const [owner, otherAccount] = await ethers.getSigners();
    const Registry = await ethers.getContractFactory("ProfileRegistry");
    registry = await upgrades.deployProxy(Registry, ["0x57317a302F8874527C5D4781993EA56814315B1C"], {
      kind: "uups",
      initializer: "initialize",
    });

    await registry.deployed();
	const currentImplAddress = await upgrades.erc1967.getImplementationAddress(
		registry.address
	);
	console.log(`Deployed at ${registry.address}`);
	console.log(`Implementation at: ${currentImplAddress}`);

	let instance = Registry.attach(registry.address)
	let checkOwner = await instance.owner();
	console.log("Owner: ",  checkOwner);
	console.log(checkOwner == owner.address)
}

// Sepolia Proxy Address: 0xCf1970abe2802522B7cA21046cEd30932AF3F305
// Sepolia Implementation Address: 0x2Cc54024Ec8861EC3Bd8D9EFD35107d0848a85EC

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
