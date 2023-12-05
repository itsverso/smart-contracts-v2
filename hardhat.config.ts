import { HardhatUserConfig } from "hardhat/config";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-chai-matchers";
require("@nomicfoundation/hardhat-chai-matchers");
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

import * as dotenv from "dotenv";

// rest of imports omitted

dotenv.config();

// Go to https://infura.io, sign up, create a new API key
// in its dashboard, and replace "KEY" with it
const INFURA_API_KEY = process.env.INFURA_PRIVATE_KEY as string;
const INFURA_API_KEY__MAINNET = process.env.INFURA_API_KEY__MAINNET as string;
// Replace this private key with your Sepolia account private key
// To export your private key from Coinbase Wallet, go to
// Settings > Developer Settings > Show private key
// To export your private key from Metamask, open Metamask and
// go to Account Details > Export Private Key
// Beware: NEVER put real Ether into testing accounts
const PRIVATE_KEY = process.env.PRIVATE_KEY as string;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
  },
  networks: {
    goerli: {
      url: INFURA_API_KEY,
      accounts: [PRIVATE_KEY],
    },
    optimism: {
      url: INFURA_API_KEY__MAINNET,
      accounts: [PRIVATE_KEY],
    },
  },
};

export default config;
