require("dotenv").config();
import { ethers, upgrades } from "hardhat";
import { Network } from "alchemy-sdk";
import VERSOS from "../data/versos-parsed-with-collects.json";
import MASTER_JSON from "../artifacts/contracts/MasterCollectionV3.sol/MasterCollectionV3.json";

async function main() {
  // Contract address
  const goerli_address = "0xbaecb366d7093053bd8c7d0a0dccf488042d670d";
  const address_mainnet = "0xF45842dD9b634e63264ABa2e49f4C6282b34b199";
  console.log("Address: ", address_mainnet);
  // Private key
  const privateKey = process.env.PRIVATE_KEY as string;
  console.log("Key: ", privateKey);
  // Alchemy API key
  const alchemyKey = process.env.ALCHEMY_KEY;
  const infuraKey = process.env.INFURA_KEY;
  console.log("Alchemy: ", alchemyKey);
  // Instantiate provider
  const InfuraProvider = new ethers.providers.InfuraProvider(
    "optimism",
    infuraKey
  );
  const Provider = new ethers.providers.AlchemyProvider("optimism", alchemyKey);
  // Create a signer with the specified private key
  const signer = new ethers.Wallet(privateKey, InfuraProvider);
  // Instantiate contract with signer
  let master = new ethers.Contract(address_mainnet, MASTER_JSON.abi, signer);

  // Token ID 51 is tokenID 182 in new contract
  let tokenId = 182;
  let collectorIndex = 1;
  let owners = VERSOS.versos[tokenId - 1].owners as string[];
  let owner = owners[collectorIndex];

  if (ethers.utils.isAddress(owner)) {
    let price = await master.getBuyPriceAfterFee(182);
    try {
      let tx = await master.collect(
        182,
        "0x6ba63e9cb1a80c9b5c202b1a87a9ff1d159f4928",
        "0x",
        {
          value: price,
          gasLimit: 150000,
        }
      );

      let receipt = await tx.wait();
      if (receipt && receipt.status == 1) {
        console.log(`Collected token ID ${tokenId} for: ${owner}`);
      } else {
        console.log(receipt);
      }
    } catch (e) {
      console.log("transaction REVERTED!");
    }
  } else {
    console.log("Not a valid owner");
  }

  console.log("");
  console.log("DONE");
  console.log("");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
