import { Network, Alchemy } from "alchemy-sdk";
const fs = require("fs");
const path = require("path");
require("dotenv");

async function main() {
  // Get the right directory
  const directory = path.join("data", "versos.json");
  // Read the contents of the JSON file
  const data = fs.readFileSync(directory);
  // Parse the JSON data into a JavaScript object
  const jsonData = JSON.parse(data);
  // Get contract
  const contract = process.env.MASTER_COLLECTION_ADDRESS as string;
  // Console.log
  console.log("Before Adding data", JSON.stringify(jsonData, null, 4));

  // Alchemy stuff
  const settings = {
    apiKey: process.env.ALCHEMY_KEY,
    network: Network.OPT_MAINNET,
  };
  // Instantiate
  const alchemy = new Alchemy(settings);
  // Fetch NFTs async
  const nftsIterable = alchemy.nft.getNftsForContractIterator(
    contract as string
  );
  // Iterate and push async
  for await (const nft of nftsIterable) {
    jsonData.versos.push(nft);
  }

  // Convert the JavaScript object back into a JSON string
  const jsonString = JSON.stringify(jsonData);

  fs.writeFileSync(directory, jsonString, "utf-8", (err: any) => {
    if (err) throw err;
    console.log("Data added to file");
  });

  const update_data = fs.readFileSync(directory);
  const updated_jsonData = JSON.parse(update_data);
  console.log("After Adding data", JSON.stringify(updated_jsonData, null, 4));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
