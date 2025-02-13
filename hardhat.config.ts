import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  networks: {
        hardhat: {
            blockGasLimit: 1000000000000 // whatever you want here
        },
    },
  gasReporter: {
        offline: true,
        currency: 'USD',
        L1: "polygon",
        currencyDisplayPrecision: 10,
        gasPrice: 30,
        tokenPrice: "1",       // ETH per ETH
        token: "ETH",
        }
};

export default config;
