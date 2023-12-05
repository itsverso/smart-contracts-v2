import { ethers } from "ethers";
import REGISTRY_ABI from "../artifacts/contracts/NewProfileRegistry.sol/ProfileRegistry.json";

export const profileRegistryAddress__Mainnet =
  "0xE28a2D68a5E2dCa28D35820aeee53AbeAeB3df25";

export const InfuraProvider = new ethers.providers.InfuraProvider(
  "optimism",
  process.env.INFURA_KEY
);

export const Registry = new ethers.Contract(
  profileRegistryAddress__Mainnet,
  REGISTRY_ABI.abi,
  InfuraProvider
);
