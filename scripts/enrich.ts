import { Network, Alchemy } from "alchemy-sdk";
import { Registry } from "../constants";
const fs = require("fs");
const path = require("path");
require("dotenv");

async function main() {
  //////////////////////////////////
  ////// Get JSON
  //////////////////////////////////
  // Get the right directory
  const raw_directory = path.join("data", "versos.json");
  // Read the contents of the JSON file
  const raw_data = fs.readFileSync(raw_directory);
  // Parse the JSON data into a JavaScript object
  const rawJsonData = JSON.parse(raw_data);

  // Get the right directory
  const enriched_directory = path.join("data", "versos-enriched.json");
  // Read the contents of the JSON file
  const enriched_data = fs.readFileSync(enriched_directory);
  // Parse the JSON data into a JavaScript object
  const enrichedJsonData = JSON.parse(enriched_data);

  //////////////////////////////////
  ////// PROCESSING
  //////////////////////////////////

  for (let i = 0; i < rawJsonData.versos.length; i++) {
    let handle = rawJsonData.versos[i].rawMetadata.creator;
    let res = await Registry.getIdFromHandle(handle);
    let id = parseInt(res._hex);
    console.log("id: ", id);
    /**
    if (id !== 0) {
      let owner = await Registry.ownerOf(id);
      return await getUserFeedFromAddress(owner);
    }
     */
  }

  //////////////////////////////////
  ////// Write back
  //////////////////////////////////
  // Convert the JavaScript object back into a JSON string
  /** 
  const jsonString = JSON.stringify(jsonData);

  fs.writeFileSync(directory, jsonString, "utf-8", (err: any) => {
    if (err) throw err;
    console.log("Data added to file");
  });

  const update_data = fs.readFileSync(directory);
  const updated_jsonData = JSON.parse(update_data);
  console.log("After Adding data", JSON.stringify(updated_jsonData, null, 4));
  */
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
