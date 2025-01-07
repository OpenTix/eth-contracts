// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

struct Event {
    uint256 count;
    string description;
}

contract VenueMint is ERC1155Holder, ERC1155 {
    address private owner;
    address private self;

    mapping (string => address) private event_to_vendor;
    uint256 last_id = 0;

    Event[] private events;

    event Event_Commencement(address indexed from, string description, string venue_URI, uint256 capacity);

    constructor() ERC1155("https://onlytickets.co/api/tokens/{id}.json") {
        owner = msg.sender;
        self = address(this);
        console.log("Contract address is ", self, " and owner address is", owner);
    }

    function create_new_event(string calldata description, string calldata from, uint256 general_admission, uint256 unique_seats) public {
        emit Event_Commencement(msg.sender, description, from, general_admission + unique_seats);

        console.log("Description is %s", description);
        console.log("Venue URL is %s", from);
        console.log("General admission is %d", general_admission);
        console.log("Unique seats is %d", unique_seats);

        /*
        uint256[] memory ids = new uint256[](unique_seats + 1);
        uint256[] memory amounts = new uint256[](unique_seats + 1);
        */ // Uncomment this if we want to try semi-fungible tickets

        uint256[] memory ids = new uint256[](unique_seats + general_admission);
        uint256[] memory amounts = new uint256[](unique_seats + general_admission);
        uint256 i = last_id;

        for (; i < last_id + ids.length; ++i) {
            ids[i] = i;
            amounts[i] = 1;

            /*
            if(i < unique_seats) {
                amounts[i] = 1;
            } else {
                amounts[i] = general_admission;
            }
            */ // Uncomment this if we want to try semi-fungible tickets

            // console.log("ids[%d] = %d", i, ids[i]);
            // console.log("amounts[%d] = %d", i, amounts[i]);
        }

        event_to_vendor[description] = msg.sender;
        events.push(Event({ description:description, count: general_admission + unique_seats}));
        last_id = i;
        _mintBatch(self, ids, amounts, "");
    }

    function getEvents() internal view returns (string[] memory) {
        string[] memory ret = new string[](100);
        uint256 j = 0;

        for (uint256 i = 0; i < events.length; ++i) {
            if (events[i].count > 0) {
                ret[j++] = string(abi.encodePacked(events[i].description, " ", Strings.toString(events[i].count)));
            }
        }

        return ret;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}