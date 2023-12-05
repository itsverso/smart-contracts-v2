import { Network, Alchemy } from "alchemy-sdk";
const fs = require("fs");
const path = require("path");
require("dotenv");

async function main() {
  // Get the right directory
  const parsed_directory = path.join(
    "data",
    "versos-parsed-with-collects.json"
  );
  // Read the contents of the JSON file
  const parsed_data = fs.readFileSync(parsed_directory);
  // Parse the JSON data into a JavaScript object
  const parsedJsonData = JSON.parse(parsed_data);
  // Get contract
  const contract = process.env.MASTER_COLLECTION_ADDRESS as string;

  // Alchemy stuff
  const settings = {
    apiKey: process.env.ALCHEMY_KEY,
    network: Network.OPT_MAINNET,
  };
  // Instantiate
  const alchemy = new Alchemy(settings);
  console.log("here");
  // For loop, double check.
  for (let i = 0; i < parsedJsonData.versos.length; i++) {
    console.log("there");
    const token = await alchemy.nft.getNftMetadata(contract, i + 1);

    if (token.tokenUri?.raw == parsedJsonData.versos[i].metadataURI) {
      const collectorAddreses = await alchemy.nft.getOwnersForNft(
        contract as string,
        i + 1
      );
      parsedJsonData.versos[i].owners = collectorAddreses.owners;
      parsedJsonData.versos[i].tokenId = token.tokenId;
      console.log("Fetched ", i + 1);
    }
    /** 
    const collectorAddreses = await alchemy.nft.getOwnersForNft(
      contract as string,
      i + 1
    );
    console.log("Fetched for tokenID: ", i + 1);
    */
  }

  // Convert the JavaScript object back into a JSON string
  const jsonString = JSON.stringify(parsedJsonData);

  fs.writeFileSync(parsed_directory, jsonString, "utf-8", (err: any) => {
    if (err) throw err;
    console.log("Data added to file");
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
