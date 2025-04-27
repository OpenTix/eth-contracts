// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "hardhat/console.sol";

// holds the minimum and maximum ids for that event
struct Ids {
    // both inclusive
    uint256 min;
    uint256 max;
    bool exists;
}

struct Event {
    uint256 count;
    string description;
    Ids ids;
    address vendor_wallet;
    uint256 ticket_cost;
}

struct EventsIndex {
    uint256 index;
    bool exists;
}

contract VenueMint is ERC1155Holder, ERC1155 {
    address private owner; // Deployer of contract (us)
    address private self; // The address of the contract (self)

    // Mapping nft ids to cost
    // mapping(uint256 => uint256) private ticket_costs;

    // Mapping ticket id to whether they are allowed to be transferred to another user
    mapping(uint256 => bool) private id_to_transferable;

    // map description to the event
    mapping(string => EventsIndex) private description_to_events_index;

    uint256 last_id = 0; // The last id that we minted

    Event[] private events;

    event Event_Commencement(
        address indexed from,
        string description,
        string venue_URI,
        uint256 capacity
    );
    event Buy_Ticket_Event(string description, uint256 count);
    event User_To_User_Transfer_Concluded(
        address indexed seller,
        address indexed buyer
    );

    // Set the owner to the deployer and self to the address of the contract
    constructor()
        ERC1155("https://client.dev.opentix.co/api/tokens/{id}.json")
    {
        owner = msg.sender;
        self = address(this);
        //console.log("Contract address is ", self, " and owner address is", owner);
    }

    function get_ticket_cost(uint256 id) view private returns (uint256) {
        for (uint256 i = 0; i < events.length; i++) {
             Ids memory tmp = events[i].ids;

            if (id >= tmp.min && id <= tmp.max) {
                return events[i].ticket_cost;
            }
        }

        return 0;
    }

    // Create a new event check the costs, emit an event being made
    function create_new_event(
        string calldata description,
        string calldata vendor_url,
        uint256 general_admission,
        uint256 unique_seats,
        uint256 cost
    ) public {
        // require(
        //     costs.length == unique_seats + general_admission,
        //     "Must provide the same number of costs as general admission and unique seats."
        // );

        emit Event_Commencement(
            msg.sender,
            description,
            vendor_url,
            general_admission + unique_seats
        );

        // Set the ids and the amounts of each along with the cost of each being minted
        uint256[] memory ids = new uint256[](unique_seats + general_admission);
        uint256[] memory amounts = new uint256[](
            unique_seats + general_admission
        );
        uint256 i = last_id;

        for (; i < last_id + ids.length; ++i) {
            ids[i - last_id] = i;
            amounts[i - last_id] = 1;
            // if (i < unique_seats) {
            //     ticket_costs[i] = costs[i - last_id];
            // } else {
            //     ticket_costs[i] = costs[costs.length - 1];
            // }
        }

        // keep track of the NFT ids for the event
        Ids memory tmp;
        tmp.min = last_id;
        tmp.max = i - 1;
        tmp.exists = true;

        EventsIndex memory tmp2;
        tmp2.exists = true;
        tmp2.index = events.length;

        description_to_events_index[description] = tmp2;
        events.push(
            Event({
                description: description,
                count: general_admission + unique_seats,
                ids: tmp,
                vendor_wallet: payable(msg.sender),
                ticket_cost: cost
            })
        );

        _mintBatch(self, ids, amounts, "");
        // Keep up with the last nft we minted;
        last_id = i;
    }

    function get_events() public view returns (string[] memory) {
        string[] memory ret = new string[](
            events.length > 100 ? 100 : events.length
        );
        uint256 j = 0;

        for (uint256 i = 0; i < events.length; ++i) {
            if (events[i].count > 0) {
                ret[j++] = string(
                    abi.encodePacked(
                        events[i].description,
                        " Capacity is ",
                        Strings.toString(events[i].count)
                    )
                );
            }
        }
        return ret;
    }

    // returns a list of all valid NFT ids for the event
    function get_event_ids(
        string calldata description
    ) public view returns (uint256[] memory, Ids memory) {
        EventsIndex memory tmp2 = description_to_events_index[description];

        // check that there is a valid description
        require(tmp2.exists, "Please provide a description for a valid event.");

        Ids memory tmp = events[description_to_events_index[description].index]
            .ids;
        uint256 count = 0;

        // figure out how big our array needs to be
        for (uint256 i = tmp.min; i <= tmp.max; i++) {
            if (balanceOf(self, i) > 0) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 j = 0;
        for (uint256 i = tmp.min; i <= tmp.max; i++) {
            if (balanceOf(self, i) > 0) {
                result[j] = i;
                j++;
            }
        }

        return (result, tmp);
    }

    // get the event description with the ticket id
    function get_event_description(
        uint256 id
    ) public view returns (string memory) {
        for (uint256 i = 0; i < events.length; i++) {
            Ids memory tmp = events[i].ids;

            if (id >= tmp.min && id <= tmp.max) {
                return events[i].description;
            }
        }
        return "";
    }

    // returns true if the description is available. false otherwise
    function is_description_available(
        string calldata description
    ) public view returns (bool) {
        return !description_to_events_index[description].exists;
    }

    // Give the cost of tickets so that we can pass that into value field on frontend
    function get_cost_for_tickets(
        uint256[] calldata ids
    ) public view returns (uint256) {
        uint256 total_cost = 0;
        for (uint256 i = 0; i < ids.length; ++i) {
            total_cost += get_ticket_cost(ids[i]);
        }
        return total_cost;
    }

    // Enable users to buy tickets (NFTs)
    function buy_tickets(
        string calldata event_description,
        uint256[] calldata ids
    ) public payable returns (bool, uint256) {
        // Make sure its a real event
        require(
            description_to_events_index[event_description].exists,
            "Please provide a description for a valid event."
        );

        // Get the total cost of each tickets
        uint256 total_cost = 0;
        for (uint256 i = 0; i < ids.length; ++i) {
            // Make sure the contract currently has these tickets
            require(
                balanceOf(self, ids[i]) > 0,
                "One of these tickets has already been sold."
            );

            total_cost += get_ticket_cost(ids[i]);
        }

        // Check if they are able to buy those tickets and that they have enough money
        require(
            total_cost > 0,
            "You are attempting to buy unavailable tickets."
        );
        require(
            msg.value >= total_cost,
            "You do not have enough money to purchase the desired tickets."
        );

        // Buy one since they're NFTs
        uint256[] memory values = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; ++i) {
            values[i] = 1;
        }

        // Transfer the money to the vendor
        (bool success, ) = events[
            description_to_events_index[event_description].index
        ].vendor_wallet.call{value: total_cost}("");
        require(success, "transfer to vender failed.");

        // Transfer the tickets to the user
        _safeBatchTransferFrom(self, msg.sender, ids, values, "");
        emit Buy_Ticket_Event(event_description, ids.length);

        return (true, total_cost);
    }

    // this enables the input user to transfer the callers tickets
    function allow_user_to_user_ticket_transfer() public {
        setApprovalForAll(self, true);
    }

    function check_ticket_transfer_permission() public view returns (bool) {
        return isApprovedForAll(msg.sender, self);
    }

    function check_ticket_transferable(
        uint256 ticketid
    ) public view returns (bool) {
        return id_to_transferable[ticketid];
    }

    function allow_ticket_to_be_transfered(uint256 ticketid) public {
        require(ticketid < last_id, "The ticket id provided is not valid.");
        require(
            balanceOf(msg.sender, ticketid) > 0,
            "Can't allow ticket transfer for a ticket you do not own."
        );

        id_to_transferable[ticketid] = true;
    }

    function disallow_ticket_to_be_transfered(uint256 ticketid) public {
        require(ticketid < last_id, "The ticket id provided is not valid.");
        require(
            balanceOf(msg.sender, ticketid) > 0,
            "Can't disallow ticket transfer for a ticket you do not own."
        );

        id_to_transferable[ticketid] = false;
    }

    // disables the contracts control of the senders tokens
    function disallow_user_to_user_ticket_transfer() public {
        setApprovalForAll(self, false);
    }

    // this should be called buy the purchaser of the ticket
    function buy_ticket_from_user(
        address user,
        uint256 ticketid
    ) public payable {
        bool tmp = id_to_transferable[ticketid];

        // we need to make sure this is a valid transfer
        require(ticketid < last_id, "The ticket id provided is not valid.");
        require(
            isApprovedForAll(user, self),
            "The seller has not authorized a transfer."
        );
        require(tmp, "This ticket id provided is not transferable.");
        require(
            balanceOf(user, ticketid) > 0,
            "Requested seller does not own the ticket."
        );

        uint256 cost = get_ticket_cost(ticketid);

        require(
            msg.value >= cost,
            "You did not send enough money to purchase the ticket."
        );

        // send the money to the user
        (bool success, ) = user.call{value: cost}("");
        require(success, "Failed to pay the user you are purchasing from.");

        // transfer the nft to the purchaser
        _safeTransferFrom(user, msg.sender, ticketid, 1, "");

        id_to_transferable[ticketid] = false;

        emit User_To_User_Transfer_Concluded(user, msg.sender);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
