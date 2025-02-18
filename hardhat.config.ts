import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
require('dotenv').config();

const poly_api_key = process.env.POLYGONSCAN_API_KEY || ""
const private_key = process.env.PRIVATE_KEY || "0000000000000000000000000000000000000000000000000000000000000000";
const coinmarketcap_api_key = process.env.COINMARKETCAP_API_KEY || ""

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      blockGasLimit: 1000000000000, // whatever you want here
    },
    polygon_amoy: {
      url: `https://rpc-amoy.polygon.technology`,
      accounts: [private_key],
    },
  },
  etherscan: {
    apiKey: poly_api_key,
  },
  gasReporter: {
    currency: 'USD',
    L1: "polygon",
    coinmarketcap: coinmarketcap_api_key,
    L1Etherscan: poly_api_key,
  },
  mocha: {
    timeout: 100000000,
  },
};

export default config;
