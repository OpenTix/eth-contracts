# eth-contracts

Repo that contains all of our smart contracts

# Testing

## Steps
* npm run rebuild - Will clean and compile all contracts in contracts/
* npx hardhat node (localhost for now)
* npx hardhat ignition deploy ./ignition/modules/VenueMint.ts --network \<network> (localhost for now)
* npx hardhat console --network \<network> (localhost for now)
    * const VenueMint = await ethers.getContractFactory("VenueMint")
    * const venuemint = await VenueMint.attach(Address provided by the deployed contract)
    * const resp = await venuemint.function(params) (const resp = await venuemint.create_new_event("test", "0xblahblahblah", general_admission, unique_seats))

# Nice to know
* [Gas Estimator](https://www.cryptoneur.xyz/en/gas-fees-calculator?usedGas=25180972&txnType=Custom)
* [Getting Started with Hardhat](https://hardhat.org/hardhat-runner/docs/getting-started)
* [Deployment with Hardhat](https://hardhat.org/tutorial/deploying-to-a-live-network)
* [Deployment and Interaction](https://docs.openzeppelin.com/learn/deploying-and-interacting)