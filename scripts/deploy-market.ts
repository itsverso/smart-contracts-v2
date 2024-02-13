import { ethers, upgrades } from "hardhat";
import PROFILE_ABI from "../artifacts/contracts/NewProfileRegistry.sol/ProfileRegistry.json";

async function main() {
	let simpleMarket;
	const [owner] = await ethers.getSigners();
    const SimpleMarket = await ethers.getContractFactory("SimpleMarketMaster");
    // Deploy proxy
    simpleMarket = await upgrades.deployProxy(
      SimpleMarket,
      [
        owner.address, // Owner
        "0x4e4753c3e3b88156255A11B401058591Dd34Ba63", // Fee destination
        "55555555555555", // Base price
      ],
      {
        kind: "uups",
        initializer: "initialize",
      }
    );
    // Await
    await simpleMarket.deployed();
	const currentImplAddress = await upgrades.erc1967.getImplementationAddress(
		simpleMarket.address
	);
	console.log(`Deployed at ${simpleMarket.address}`);
	console.log(`Implementation at: ${currentImplAddress}`);

	let instance = SimpleMarket.attach(simpleMarket.address)
	let base = await instance.getBasePrice()
	console.log(base)
	let checkOwner = await instance.owner();
	console.log("Owner: ",  checkOwner);
	console.log(checkOwner == owner.address)
}

// Sepolia Proxy Address: 0xf6FC826bD937c4aA4377E201275b7B6B5379F47A
// Sepolia Implementation Address: 0xc97c3dA66F96267597462dC3D2277edF8f742f68

// Goerli Simple Proxy Address: 0x7616F0BC60240B5D88839b868485b47d8f32824C
// Goerli Simple Implementation Address: 0x5a7416b356B900C4b075D0823A755cc4c55E4953

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
