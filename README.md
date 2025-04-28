# eth-contracts

Repo that contains all of our smart contracts

# Deploying

Deploy: `npm run deploy`

Generate ABI: `npm run generate_abi_wsl` or `npm run generate_abi`
* non-wsl version uses the solc-windows.exe from the repo.

# Testing

* Run automated tests with `npx hardhat test`

# Current deployed address

0x8BE301eD017D23977F98b48CD9D18EaB91C0ae26

## Mainnet

0xeB60D2D16F2D48324C84D9ffB26465A88d40659f

## Steps
* npm run rebuild - Will clean and compile all contracts in contracts/
* npx hardhat node (localhost for now)
* npx hardhat ignition deploy ./ignition/modules/VenueMint.ts --network \<network> (localhost for now)
* npx hardhat console --network \<network> (localhost for now)
    * const VenueMint = await ethers.getContractFactory("VenueMint")
    * const venuemint = await VenueMint.attach(Address provided by the deployed contract)
    * const resp = await venuemint.function(params) (const resp = await venuemint.create_new_event("test", "0xblahblahblah", general_admission, unique_seats))

# Depolyment

To deploy run `npx hardhat ignition deploy ./ignition/modules/VenueMint.ts --network polygon_amoy`.

To deploy you need some stuff. First you need a polygonscan API key defined as POLYGONSCAN_API_KEY in the .env. Second you need your wallet (that is connected to amoy with some balance) private key in the .env file as PRIVATE_KEY.

So there are two ways to do this. The dumb was is how I did it. Basically, you buy ETH ($20 min) then you swap that ETH to POL (Polygon Ecosystem Token). However that Polygon is still on the ETH net. So we bridge that to POL on the Polgon POS net. (This bridge takes 20 minutes and about $2) After doing this you can then drip using the polygon amoy faucet.

The other way to do it would be to buy POL on the Polygon POS network. I didn't realize this was an option originally thus the dumb way was invented.

I used metamask as my wallet and bought the ETH through them.

[This is a good faucet](https://faucet.stakepool.dev.br/amoy)

* [Polygon Portal (Bridging and checking your balances)](https://portal.polygon.technology/assets)
* [Polgon Amoy Faucet](https://www.alchemy.com/faucets/polygon-amoy)

# Nice to know
* [Gas Estimator](https://www.cryptoneur.xyz/en/gas-fees-calculator?usedGas=25180972&txnType=Custom)
* [Getting Started with Hardhat](https://hardhat.org/hardhat-runner/docs/getting-started)
* [Deployment with Hardhat](https://hardhat.org/tutorial/deploying-to-a-live-network)
* [Deployment and Interaction](https://docs.openzeppelin.com/learn/deploying-and-interacting)