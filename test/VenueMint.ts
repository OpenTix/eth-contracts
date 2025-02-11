import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { contracts } from "../typechain-types";
import { expect } from "chai";
import hre from "hardhat";

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

        // basic check to make sure the MintBatch event is properly emitted
        it("should emit a mint batch event", async () => {
            const contract = await loadFixture(deployOne);
            expect(await contract.create_new_event("test", "0xblahblahblah", 1, 0, [5])).to.emit(contract, "MintBatch");
        })
    })
})
