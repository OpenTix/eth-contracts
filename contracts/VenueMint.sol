// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

struct Event {
    uint256 count;
    string description;
}

contract VenueMint is ERC1155Holder, ERC1155 {
    address private owner; // Deployer of contract (us)
    address private self; // The address of the contract (self)

    mapping (string => address payable) private event_to_vendor; // Mapping event descriptions to vendor wallets
    mapping (uint256 => uint256) private ticket_costs; // Mapping nft ids to cost

    uint256 last_id = 0; // The last id that we minted

    Event[] private events;

    event Event_Commencement(address indexed from, string description, string venue_URI, uint256 capacity);
    event Buy_Ticket_Event(string description, uint256 count);

    // Set the owner to the deployer and self to the address of the contract
    constructor() ERC1155("https://onlytickets.co/api/tokens/{id}.json") {
        owner = msg.sender;
        self = address(this);
        //console.log("Contract address is ", self, " and owner address is", owner);
    }

    // Create a new event check the costs, emit an event being made
    function create_new_event(string calldata description, string calldata vendor_url, uint256 general_admission, uint256 unique_seats, uint256[] calldata costs) public returns (bool) {
        require(costs.length == unique_seats + general_admission, "Must provide the same number of costs as general admission and unique seats.");

        emit Event_Commencement(msg.sender, description, vendor_url, general_admission + unique_seats);

        //console.log("Description is %s", description);
        //console.log("Venue URL is %s", from);
        //console.log("General admission is %d", general_admission);
        //console.log("Unique seats is %d", unique_seats);

        /*
        uint256[] memory ids = new uint256[](unique_seats + 1);
        uint256[] memory amounts = new uint256[](unique_seats + 1);
        */ // Uncomment this if we want to try semi-fungible tickets

        // Set the ids and the amounts of each along with the cost of each being minted
        uint256[] memory ids = new uint256[](unique_seats + general_admission);
        uint256[] memory amounts = new uint256[](unique_seats + general_admission);
        uint256 i = last_id;

        for (; i < last_id + ids.length; ++i) {
            ids[i - last_id] = i;
            amounts[i - last_id] = 1;
            if (i < unique_seats) {
                ticket_costs[i] = costs[i - last_id];
            } else {
                ticket_costs[i] = costs[costs.length - 1];
            }

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

        // Track the vendor wallet so they can be paid when someone buys a ticket to their event
        // Save the event to events
        event_to_vendor[description] = payable(msg.sender);
        events.push(Event({ description:description, count: general_admission + unique_seats}));

        _mintBatch(self, ids, amounts, "");
        // Keep up with the last nft we minted;
        last_id = i;
        return true;
    }

    function get_events() public view returns (string[] memory) {
        string[] memory ret = new string[](events.length > 100 ? 100 : events.length);
        uint256 j = 0;

        for (uint256 i = 0; i < events.length; ++i) {
            if (events[i].count > 0) {
                ret[j++] = string(abi.encodePacked(events[i].description, " Capacity is ", Strings.toString(events[i].count)));
            }
        }

        return ret;
    }

    // Enable users to buy tickets (NFTs)
    function buy_tickets(string calldata event_description, uint256[] calldata ids) payable public returns (bool, uint256) {
        // Get the total cost of each tickets
        uint256 total_cost = 0;
        for (uint256 i = 0; i < ids.length; ++i) {
            total_cost += ticket_costs[ids[i]];
        }

        // Check if they are able to buy those tickets and that they have enough money
        if (total_cost == 0 || msg.value < total_cost) {
            return (false, 0);
        } else {
            // Buy one since they're NFTs
            uint256[] memory values = new uint256[](ids.length);
            for (uint256 i = 0; i < ids.length; ++i) {
                values[i] = 1;
            }

            // Transfer the money to the vendor
            (bool success, ) = event_to_vendor[event_description].call{value:total_cost}("");
            require(success, "transfer to vender failed.");

            // Transfer the tickets to the user
            _safeBatchTransferFrom(self, msg.sender, ids, values, "");
            emit Buy_Ticket_Event(event_description, ids.length);
            
            // 0 out the costs so that we can't double sell tickets
            for (uint256 i = 0; i < ids.length; ++i) {
                ticket_costs[ids[i]] = 0;
            }

            return (true, total_cost);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}