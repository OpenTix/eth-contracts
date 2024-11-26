// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "hardhat/console.sol";

contract VenueMint is ERC1155Holder, ERC1155 {
    address private owner;
    address private self;

    event Event_Commencement(address indexed from, string description, string venue_URI, uint256 capacity);

    constructor() ERC1155("https://onlytickets.co/api/tokens/{id}.json") {
        owner = msg.sender;
        self = address(this);
        console.log("Contract address is 0x%x and owner address is 0x%x", self, owner);
    }

    function create_new_event(string calldata description, string calldata from, uint256 general_admission, uint256 unique_seats) public {
        emit Event_Commencement(msg.sender, description, from, general_admission + unique_seats);

        console.log("Description is %s", description);
        console.log("Venue URL is %s", from);
        console.log("General admission is %d", general_admission);
        console.log("Unique seats is %d", unique_seats);

        uint256[] memory ids = new uint256[](unique_seats + 1);
        uint256[] memory amounts = new uint256[](unique_seats + 1);

        for (uint256 i = 0; i < ids.length; ++i) {
            ids[i] = i;
            if(i < unique_seats) {
                amounts[i] = 1;
            } else {
                amounts[i] = general_admission;
            }
            console.log("ids[%d] = %d", i, ids[i]);
            console.log("amounts[%d] = %d", i, amounts[i]);
        }

        
        _mintBatch(self, ids, amounts, "");
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}