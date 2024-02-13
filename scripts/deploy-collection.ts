import { ethers, upgrades } from "hardhat";
import PROFILE_ABI from "../artifacts/contracts/NewProfileRegistry.sol/ProfileRegistry.json";

async function main() {
	const [owner, otherAccount] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("CollectionFactory");
	const collectionFactory = Factory.attach("0x8BeA755CF42056b7C65FFC89846ffa472B829755")

	let tx = await collectionFactory.createCollection({
        _collectionName: "First Collection",
        _collectionMetadataURI: "https://arweave.net/C4htVOEblNnOjXT251919X0O3rLyE-BpxVKS6YQocKo",
        _readType: 0,
        _writeType: 1,
        _collectionPermissions: "0x0000000000000000000000000000000000000000",
        _minimumBalance: 0,
        _marketAddress: "0x7616F0BC60240B5D88839b868485b47d8f32824C",
        _supplyLimit: 10,
        _tokenPrice: 0,
        _isBonded: false,
    });

	let receipt = await tx.wait();

	const CollectionInstance = await ethers.getContractFactory("Collection");
	let collection = CollectionInstance.attach(receipt.logs[0].address);
	console.log('Collection Deployed at: ', receipt.logs[0].address)
	let name = await collection.name()
	console.log("With name: ", name)
}

// Sepolia Proxy Address: 0xCf1970abe2802522B7cA21046cEd30932AF3F305
// Sepolia Implementation Address: 0x2Cc54024Ec8861EC3Bd8D9EFD35107d0848a85EC

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
