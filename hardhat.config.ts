import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    sonicTestnet: {
      url: "https://rpc.testnet.soniclabs.com",
      accounts: process.env.SONIC_PRIVATE_KEY
        ? [process.env.SONIC_PRIVATE_KEY]
        : [],
    },
    blastSepolia: {
      url: "https://sepolia.blast.io",
      accounts: [process.env.BLAST_SEPOLIA_PRIVATE_KEY || ""],
    },
  },
  etherscan: {
    apiKey: {
      blastSepolia: process.env.BLAST_SEPOLIA_API_KEY as string,
    },
    customChains: [
      {
        network: "blastSepolia",
        chainId: 168587773,
        urls: {
          apiURL: "https://api-sepolia.blastscan.io/api",
          browserURL: "https://sepolia.blastscan.io/",
        },
      },
    ],
  },
  sourcify: {
    enabled: false,
  },
  defaultNetwork: "hardhat",
};

export default config;
