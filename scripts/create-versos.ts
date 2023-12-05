require("dotenv").config();
import { ethers, upgrades } from "hardhat";
import { Network } from "alchemy-sdk";
import VERSOS from "../data/versos-parsed.json";
import MASTER_JSON from "../artifacts/contracts/MasterCollectionV3.sol/MasterCollectionV3.json";

async function main() {
  // Addresses
  const address_mainnet = "0xF45842dD9b634e63264ABa2e49f4C6282b34b199";
  const address = "0xbaecb366d7093053bd8c7d0a0dccf488042d670d"; // Goerli
  // Private key
  const privateKey = process.env.PRIVATE_KEY as string;
  console.log("Key: ", privateKey);
  // Alchemy API key
  const alchemyKey = process.env.ALCHEMY_KEY;
  console.log("Alchemy: ", alchemyKey);
  // Instantiate provider
  const Provider = new ethers.providers.AlchemyProvider("optimism", alchemyKey);
  // Instantiate signer
  const signer = new ethers.Wallet(privateKey, Provider);
  // Instatiate contract
  let master = new ethers.Contract(address_mainnet, MASTER_JSON.abi, signer);
  // Quick check
  let name = await master.name();
  console.log("Name: ", name);

  let tx = await master.adminCreate(VERSOS.versos.slice(0, 50));

  let balance = await master.balanceOf(VERSOS.versos[0].creator, 1);
  console.log("Balance: ", balance);
  console.log(balance.toString() === "1");

  let creator = await master.creator(4);
  console.log("Is creator set: ", creator === VERSOS.versos[3].creator);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
