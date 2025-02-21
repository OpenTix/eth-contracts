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

// holds the minimum and maximum ids for that event
struct Ids {
    // both inclusive
    uint256 min;
    uint256 max;
    bool exists;
}

struct Transferable {
    bool transferable;
    bool exists;
}

contract VenueMint is ERC1155Holder, ERC1155 {
    address private owner; // Deployer of contract (us)
    address private self; // The address of the contract (self)

    mapping (string => address payable) private event_to_vendor; // Mapping event descriptions to vendor wallets
    mapping (uint256 => uint256) private ticket_costs; // Mapping nft ids to cost
    mapping (uint256 => uint256) private original_ticket_costs; // mapping nft ids to their original costs (ticket_costs gets zero'd on purchase)
    mapping (string => Ids) private event_to_ids; // Mapping event descriptions to NFT ids
    mapping (uint256 => Transferable) private id_to_transferable; // Mapping ticket id to whether they are allowed to be transferred to another user

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
    function create_new_event(string calldata description, string calldata vendor_url, 
                              uint256 general_admission, uint256 unique_seats, 
                              uint256[] calldata costs) public returns (bool) {
        require(costs.length == unique_seats + general_admission,
                "Must provide the same number of costs as general admission and unique seats.");

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
                original_ticket_costs[i] = costs[i - last_id];
            } else {
                ticket_costs[i] = costs[costs.length - 1];
                original_ticket_costs[i] = costs[costs.length - 1];
            }

            id_to_transferable[i].exists = true;


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

        // keep track of the NFT ids for the event
        Ids memory tmp;
        tmp.min = last_id;
        tmp.max = i-1;
        tmp.exists = true;
        event_to_ids[description] = tmp;

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
                ret[j++] = string(abi.encodePacked(events[i].description,
                                  " Capacity is ", Strings.toString(events[i].count)));
            }
        }
        return ret;
    }

    // returns a list of all valid NFT ids for the event
    function get_event_ids(string calldata description) public view returns (uint256[] memory) {
        Ids memory tmp = event_to_ids[description];
        uint256 count = 0;

        // check that there is a valid description
        require(tmp.exists, "Please provide a description for a valid event.");

        // figure out how big our array needs to be
        for (uint256 i = tmp.min; i <= tmp.max; i++) {
            if (ticket_costs[i] != 0) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count); 
        uint256 j = 0;
        for (uint256 i = tmp.min; i <= tmp.max; i++) {
            if (ticket_costs[i] != 0) {
                //console.log(i);
                result[j] = i;
                j++;
            }
        }

        return result;
    }

    // returns true if the description is available. false otherwise
    function is_description_available(string calldata description) public view returns (bool) {
        return !event_to_ids[description].exists;
    }

    // Enable users to buy tickets (NFTs)
    function buy_tickets(string calldata event_description, uint256[] calldata ids) payable public
    returns (bool, uint256) {
        // Get the total cost of each tickets
        uint256 total_cost = 0;
        for (uint256 i = 0; i < ids.length; ++i) {
            total_cost += ticket_costs[ids[i]];
        }

        // Check if they are able to buy those tickets and that they have enough money
        require (total_cost > 0, "You are attempting to buy unavailable tickets.");
        require(msg.value >= total_cost, "You do not have enough money to purchase the desired tickets.");
        
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

    // this enables the input user to transfer the callers tickets
    function allow_user_to_user_ticket_transfer(uint256 ticketid) public returns (bool) {
        Transferable memory tmp = id_to_transferable[ticketid];
        require(tmp.exists, "The ticket id provided is not valid.");

        id_to_transferable[ticketid].transferable = true;

        console.log(self);
        setApprovalForAll(self, true);
        return true;
    }

    function buy_ticket_from_user(address user, uint256 ticketid) payable public returns (bool) {
        Transferable memory tmp = id_to_transferable[ticketid];

        require(tmp.exists, "The ticket id provided is not valid.");
        require(tmp.transferable, "This ticket id provided is not transferable.");
        require(msg.value >= original_ticket_costs[ticketid],"You did not send enough money to purchase the ticket.");

        (bool success, ) = user.call{value:original_ticket_costs[ticketid]}("");
        require(success, "Failed to pay the user you are purchasing from.");

        _safeTransferFrom(user, msg.sender, ticketid, 1, "");

        id_to_transferable[ticketid].transferable = false;

        return true;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC1155Holder)
    returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}