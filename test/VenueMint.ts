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

        // tests if 2 NFTs can be created
        it("can create multiple nfts", async () => {
            const contract = await loadFixture(deployOne);
            const contract_address = await contract.getAddress();
            await contract.create_new_event("test", contract_address, 2, 0, [5, 5]);
            expect(await contract.balanceOfBatch([contract_address, contract_address], [0,1])).to.eql([1n,1n])
        })

        // tests if the contract properly generates NFTs after generating other ones
        // does this for a relatively small number of NFTs
        it("can create 100-1000 NFTs", async () => {
            const contract = await loadFixture(deployOne);
            const contract_address = await contract.getAddress();
            let max = 10;
            let base = 100;
            let total_so_far = 0;

            for(let i = 1; i <= max; i++) {
                // create the events
                await contract.create_new_event(`test ${i*base}`, contract_address, i*base, 0, Array(i*base).fill(5));

                // check that the contract owns all the events
                expect(await contract.balanceOfBatch(Array(i*base).fill(contract_address), Array.from({length: i*base}, (_, i) => i + total_so_far))).to.eql(Array(i*base).fill(1n));
                total_so_far += i*max;
            }
        })

        it("can get the ids of an event", async () => {
            const contract = await loadFixture(deployOne);

            const tmp = await contract.create_new_event("test", "0xblahblah", 5, 0, [5,5,5,5,5]);

            // check that it returns properly for a valid and non valid event
            const tmp2 = await contract.get_event_ids("test");
            expect(tmp2).to.eql(Array(0n,4n));

            const tmp3 = await contract.get_event_ids("");
            expect(tmp3).to.eql(Array(0n,0n));
        })

        describe("Vendor Payment Functionality", function () {

            // checks that the vendor recieves the funds from one transaction
            it("properly pays the vender", async () => {
                const init_contract = await loadFixture(deployOne);
                let min_cost = 5;
                let max_cost = 100000;
                const minCeiled = Math.ceil(min_cost);
                const maxFloored = Math.floor(max_cost);

                // randomly calculate cost of the ticket
                let ticket_cost =  Math.floor(Math.random() * (maxFloored - minCeiled) + minCeiled);

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
                const tmp = await vender_contract_instance.create_new_event("test", address, 1, 0, [ticket_cost]);

                // attach the contract to the user wallet
                // this means when we call the contracts functions the
                // sender (signer) will be the user wallet
                const user_contract_instance = vender_contract_instance.connect(userWallet)

                const vendor_balance_before = await ethers.provider.getBalance(address);

                // buy the tickets (way too much money give here)
                const resp = await user_contract_instance.buy_tickets("test", [0], {value: ethers.parseEther("1")});

                const vendor_balance_after = await ethers.provider.getBalance(address);

                // check that the vender wallet gained the correct amount of money
                expect(vendor_balance_after - vendor_balance_before).is.equal(ticket_cost);
            }) 

            // checks that the vendor is paid properly when batch buying tickets
            it("properly pays the vender when batch buying multiple tickets", async () => {
                const init_contract = await loadFixture(deployOne);
                let min_cost = 5;
                let max_cost = 100000;
                const minCeiled = Math.ceil(min_cost);
                const maxFloored = Math.floor(max_cost);

                // randomly calculate cost of the ticket
                let ticket_cost =  Math.floor(Math.random() * (maxFloored - minCeiled) + minCeiled);

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
                const tmp = await vender_contract_instance.create_new_event("test", address, 2, 0, [ticket_cost, ticket_cost]);

                // attach the contract to the user wallet
                // this means when we call the contracts functions the
                // sender (signer) will be the user wallet
                const user_contract_instance = vender_contract_instance.connect(userWallet)

                const vendor_balance_before = await ethers.provider.getBalance(address);

                // buy the tickets (way too much money give here)
                const resp = await user_contract_instance.buy_tickets("test", [0,1], {value: ethers.parseEther("1")});

                const vendor_balance_after = await ethers.provider.getBalance(address);

                // check that the vender wallet gained the correct amount of money
                expect(vendor_balance_after - vendor_balance_before).is.equal(ticket_cost*2);
            })

            // checks that the vendor is paid properly when buying multiple tickets separately
            it("properly pays the vender when buying multiple tickets in individual transactions", async () => {
                const init_contract = await loadFixture(deployOne);
                let min_cost = 5;
                let max_cost = 100000;
                const minCeiled = Math.ceil(min_cost);
                const maxFloored = Math.floor(max_cost);

                // randomly calculate cost of the ticket
                let ticket_cost =  Math.floor(Math.random() * (maxFloored - minCeiled) + minCeiled);

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
                const tmp = await vender_contract_instance.create_new_event("test", address, 2, 0, [ticket_cost, ticket_cost]);

                // attach the contract to the user wallet
                // this means when we call the contracts functions the
                // sender (signer) will be the user wallet
                const user_contract_instance = vender_contract_instance.connect(userWallet)

                const vendor_balance_before = await ethers.provider.getBalance(address);

                // buy the tickets (way too much money give here)
                const resp = await user_contract_instance.buy_tickets("test", [0], {value: ethers.parseEther("1")});
                const resp2 = await user_contract_instance.buy_tickets("test", [1], {value: ethers.parseEther("1")});
                
                const vendor_balance_after = await ethers.provider.getBalance(address);
                
                // check that the vender wallet gained the correct amount of money
                expect(vendor_balance_after - vendor_balance_before).is.equal(ticket_cost*2);
            })

            // checks that the vendor is paid properly when mutliple users buy a ticket
            it("properly pays the vender when multiple users buy a ticket", async () => {
                const init_contract = await loadFixture(deployOne);
                let min_cost = 5;
                let max_cost = 100000;
                const minCeiled = Math.ceil(min_cost);
                const maxFloored = Math.floor(max_cost);

                // randomly calculate cost of the ticket
                let ticket_cost =  Math.floor(Math.random() * (maxFloored - minCeiled) + minCeiled);

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

                // second user wallet and address
                const userWallet2 = ethers.Wallet.createRandom().connect(ethers.provider)
                const userAddress2 = await userWallet2.getAddress()

                // add a ton of fake money to the second user wallet
                ethers.provider.send("hardhat_setBalance", [userAddress2, "0xFFFFFFFFFFFFFFFFFFFFF"])

                // create the event
                const tmp = await vender_contract_instance.create_new_event("test", address, 2, 0, [ticket_cost, ticket_cost]);

                // attach the contract to the user wallet
                // this means when we call the contracts functions the
                // sender (signer) will be the user wallet
                const user_contract_instance = vender_contract_instance.connect(userWallet);

                const vendor_balance_before = await ethers.provider.getBalance(address);

                // buy the tickets (way too much money give here)
                const resp = await user_contract_instance.buy_tickets("test", [0], {value: ethers.parseEther("1")});

                const user2_contract_instance = user_contract_instance.connect(userWallet2);

                const resp2 = await user2_contract_instance.buy_tickets("test", [1], {value: ethers.parseEther("1")});
                
                const vendor_balance_after = await ethers.provider.getBalance(address);
                
                // check that the vender wallet gained the correct amount of money
                expect(vendor_balance_after - vendor_balance_before).is.equal(ticket_cost*2);
            })

            // checks that the vendor is paid properly when mutliple users buy multiple tickets
            it("properly pays the vender when multiple users buy multiple tickets", async () => {
                const init_contract = await loadFixture(deployOne);
                let min_cost = 5;
                let max_cost = 100000;
                const minCeiled = Math.ceil(min_cost);
                const maxFloored = Math.floor(max_cost);

                // randomly calculate cost of the ticket
                let ticket_cost =  Math.floor(Math.random() * (maxFloored - minCeiled) + minCeiled);

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

                // second user wallet and address
                const userWallet2 = ethers.Wallet.createRandom().connect(ethers.provider)
                const userAddress2 = await userWallet2.getAddress()

                // add a ton of fake money to the second user wallet
                ethers.provider.send("hardhat_setBalance", [userAddress2, "0xFFFFFFFFFFFFFFFFFFFFF"])

                // create the event
                const tmp = await vender_contract_instance.create_new_event("test", address, 4, 0, [ticket_cost, ticket_cost, ticket_cost, ticket_cost]);

                // attach the contract to the user wallet
                // this means when we call the contracts functions the
                // sender (signer) will be the user wallet
                const user_contract_instance = vender_contract_instance.connect(userWallet);

                const vendor_balance_before = await ethers.provider.getBalance(address);

                // buy the tickets (way too much money give here)
                const resp = await user_contract_instance.buy_tickets("test", [0,1], {value: ethers.parseEther("1")});

                const user2_contract_instance = user_contract_instance.connect(userWallet2);

                const resp2 = await user2_contract_instance.buy_tickets("test", [2,3], {value: ethers.parseEther("1")});
                
                const vendor_balance_after = await ethers.provider.getBalance(address);

                // check that the vender wallet gained the correct amount of money
                expect(vendor_balance_after - vendor_balance_before).is.equal(ticket_cost*4);
            })
        })
    })
})
