import { Network, Alchemy } from "alchemy-sdk";
const fs = require("fs");
const path = require("path");
require("dotenv");

async function main() {
  const contract = process.env.MASTER_COLLECTION_ADDRESS as string;
  const goerli_contract = "0xbaecb366d7093053bd8c7d0a0dccf488042d670d";
  const main_contract = "0xF45842dD9b634e63264ABa2e49f4C6282b34b199";
  // Alchemy stuff
  const main_settings = {
    apiKey: process.env.ALCHEMY_KEY,
    network: Network.OPT_MAINNET,
  };

  const goerli_settings = {
    apiKey: process.env.ALCHEMY_KEY,
    network: Network.OPT_GOERLI,
  };
  // Instantiate
  const main_alchemy = new Alchemy(main_settings);
  const goerli_alchemy = new Alchemy(goerli_settings);

  for (let i = 0; i < 7; i++) {
    const tokenId = 7;
    const main_collectorAddreses = await main_alchemy.nft.getOwnersForNft(
      contract,
      i + 1
    );

    const mainv3_collectorAddreses = await main_alchemy.nft.getOwnersForNft(
      main_contract,
      i + 1
    );
    const goerli_collectorAddreses = await goerli_alchemy.nft.getOwnersForNft(
      goerli_contract,
      i + 1
    );

    for (let z = 0; z < main_collectorAddreses.owners.length; z++) {
      console.log(main_collectorAddreses.owners[z]);
      console.log(mainv3_collectorAddreses.owners[z]);
      console.log(`For token ${i + 1} and collector at index ${z}:`);
      console.log(
        main_collectorAddreses.owners[z] == mainv3_collectorAddreses.owners[z]
      );
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
