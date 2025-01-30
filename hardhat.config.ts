import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  networks: {
        hardhat: {
            blockGasLimit: 1000000000000 // whatever you want here
        },
    }
};

export default config;
