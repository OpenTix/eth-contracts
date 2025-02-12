import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { contracts } from "../typechain-types";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

// overall testing framework
describe("VenueMint", function () {

    // function for deploying
    // when called from loadFixture it will only actually be called once
    // then stored for later calls
    async function deployOne() {
        const VenueMint = await hre.ethers.getContractFactory("VenueMint");
        const contract = await VenueMint.deploy();
        return contract;
    }

    // check core functionality of the contract
    describe("Core Functionality", function () {
        // check that the contract properly deploys
        it("should deploy", async () => {
            const contract = await loadFixture(deployOne);
            expect(contract).to.be;
        })

        // basic check to make sure the create_new_event function is creating NFTs
        // this checks that the contract owns the nft after creation
        it("can create an nft", async () => {
            const contract = await loadFixture(deployOne);
            await contract.create_new_event("test", "0xblahblahblah", 1, 0, [5])
            expect(await contract.balanceOfBatch([await contract.getAddress()], [0])).to.eql([1n])
        })

        // checks that purchasing a single ticket works with a separate user and vendor wallet
        it("can purchase single ticket", async () => {
            const init_contract = await loadFixture(deployOne);

            // vendor wallet and address
            const wallet = ethers.Wallet.createRandom().connect(ethers.provider);
            const address = await wallet.getAddress();

            // add a ton of fake money to the vendor wallet
            const vender_contract_instance = init_contract.connect(wallet);

            ethers.provider.send("hardhat_setBalance", [address, "0xFFFFFFFFFFFFFFFFFFFFF"])
            
            // user wallet and address
            const userWallet = ethers.Wallet.createRandom().connect(ethers.provider);
            const userAddress = await userWallet.getAddress();
            
            // add a ton of fake money to the user wallet
            ethers.provider.send("hardhat_setBalance", [userAddress, "0xFFFFFFFFFFFFFFFFFFFFF"])
            
            // create the event
            const tmp = await vender_contract_instance.create_new_event("test", address, 1, 0, [5000])
            
            // attach the contract to the user wallet
            // this means when we call the contracts functions the
            // sender (signer) will be the user wallet
            const user_contract_instance = vender_contract_instance.connect(userWallet)

            // buy the tickets (way too much money give here)
            const resp = await user_contract_instance.buy_tickets("test", [0], {value: ethers.parseEther("1")});

            // check that the user wallet now owns the NFT
            expect(await user_contract_instance.balanceOfBatch([userAddress], [0])).to.eql([1n]);
        })

        it("can create multiple nfts", async () => {
            const contract = await loadFixture(deployOne);
            const contract_address = await contract.getAddress();
            await contract.create_new_event("test", contract_address, 2, 0, [5, 5]);
            expect(await contract.balanceOfBatch([contract_address, contract_address], [0,1])).to.eql([1n,1n])
        })
    })
})
