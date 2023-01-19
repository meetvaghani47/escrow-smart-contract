  // SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

 contract escrow {

     
      enum Available {NO, YES}

      enum Status {
          OPEN,
          PENDING,
          DELEVERY,
          CONFIRMED,
          DISPUTED,
          REFUNDED,
          WITHDRAWED
      }


      struct ItemStruct {
          uint itemID;
          string purpose;
          uint amount;
          address owner;
          address supplier;
          Status status;
          bool provided;
          bool confirmed;
          uint timestamp;
      }

      address public escAcc;
       uint public escBal;
      uint public escAvailBal;
      uint public escFee;
      uint public totalItems;
      uint public totalConfirmed;
      uint public totalDisputed;

      mapping(uint => ItemStruct)  items; 
      mapping(address => ItemStruct[]) itemsOf;
      mapping(address => mapping(uint => bool)) public requested;
      mapping(uint => address) public ownerOf;
      mapping(uint => Available) public isAvailable; 

    event Action (
        uint itemID,
        string actiontype,
        Status status,
        address indexed executor

    );

        constructor(uint _escFee) {
            escAcc = msg.sender;
            escFee = _escFee;
        }

         function createItem(string memory purpose) public payable returns (bool) {
             require(bytes(purpose).length > 0, "purpose cannot be empty" );
             require(msg.value > 0 ether, "amount cannot be zero");

             uint itemID = totalItems++;
             ItemStruct storage item = items[itemID]; 
             item.itemID = itemID;
             item.purpose = purpose;
             item.amount = msg.value;
             item.timestamp = block.timestamp;
             item.owner = msg.sender;
 
             itemsOf[msg.sender].push(item);
             ownerOf[itemID] = msg.sender;             
             isAvailable[itemID] = Available.YES;
             escBal += msg.value;

             emit Action (
                  itemID,
                  "ITEM CREATED",
                 Status.OPEN,
                 msg.sender    
             );

                return true;
         }

            function getItems() public view returns (ItemStruct[] memory props) {
                props = new ItemStruct[] (totalItems);

                for(uint i=0; i < totalItems; i++ ) {
                    props[i] = items[i];
                }
            }

            function getItem(uint itemID)public view returns (ItemStruct memory) {
                return items[itemID];
            }
 
            function myItems() public view returns (ItemStruct[] memory) {
                return itemsOf[msg.sender];
            }

            function requestItem(uint itemID) public returns (bool) {
                require(msg.sender != ownerOf[itemID], "Owner not allowed");
                require(isAvailable[itemID] == Available.YES, "Item not available");

                requested[msg.sender][itemID] = true;

                emit Action(
                    itemID,
                    "ITEM REQUESTED",
                    Status.OPEN,
                    msg.sender
                );

                return true;
            }
            
            function approveRequest(uint itemID, address supplier) public returns (bool) {
                require(msg.sender == ownerOf[itemID], "only owner allowed");
                require(isAvailable[itemID] == Available.YES, "Item not available");
                require(requested[supplier][itemID], "supplier not on the list");

                items[itemID].supplier = supplier;
                 items[itemID].status = Status.PENDING;
                isAvailable[itemID] = Available.NO; 

                 emit Action(
                    itemID,
                    "ITEM APPROVED",
                    Status.PENDING,
                    msg.sender
                 );

                return true;
            }

            function performDelivery(uint itemID) public returns (bool) {
                require(msg.sender == items[itemID].supplier,  "you are not approved supplier");
                require(!items[itemID].provided, "you have already deliverd this item");
                require(!items[itemID].confirmed, "you have already confirmed this item");

                items[itemID].provided = true;
                items[itemID].status = Status.DELEVERY;

                emit Action(
                    itemID,
                    "ITEM DELIVERY INITIATED",
                    Status.DELEVERY,
                    msg.sender
                );
                return true;
            }

            function confirmDelievery(uint itemID, bool provided) public returns (bool) {
                 require(msg.sender == ownerOf[itemID],  "only owner allowed");
                 require(items[itemID].provided, "you have not deliverd this item");
                 require(items[itemID].status != Status.REFUNDED, "Already refunded,create a new Item instea"); 

                 if (provided) {
                     uint fee = (items[itemID].amount * escFee) / 100;
                     uint amount = items[itemID].amount - fee;
                     payTo (items[itemID].supplier, amount);
                     escBal -=items[itemID].amount; 
                     escAvailBal += fee;

                     items[itemID].confirmed = true;
                     items[itemID].status = Status.CONFIRMED;
                     totalConfirmed++;

              emit Action(
                    itemID,
                    "ITEM CONFIRMED",
                    Status.CONFIRMED,
                    msg.sender
                );

                 } else {
                     items[itemID].status = Status.DISPUTED;

                 emit Action(
                    itemID,
                    "ITEM DISPUTED",
                    Status.DISPUTED,
                    msg.sender
                 );

                 }
                 return true;
                 
            }

             function reFundItem(uint itemID) public returns (bool) {
                 require(msg.sender == escAcc, "only Escrow admin allowed");
                 require(!items[itemID].provided, "you have already deliverd this item");

                 payTo(items[itemID].owner, items[itemID].amount);
                 escBal -= items[itemID].amount;
                 items[itemID].status = Status.REFUNDED;
                 totalDisputed++;

                   emit Action(
                    itemID,
                    "ITEM REFUNDED",
                    Status.REFUNDED,
                    msg.sender
                );
                return true;
             }

              function withdrawfund(address to, uint amount) public returns (bool) {
                  require(msg.sender == escAcc, "only escrow admin allowed");
                  require(amount <= escAvailBal, "insufficient fund");

                  payTo(to, amount);
                  escAvailBal -= amount;
     
                    return true;
              }

            function payTo(address to, uint amount) internal returns (bool) {
                (bool succeeded, ) = payable(to).call{value: amount}("");
                require(succeeded, "payment failed");
                return true; 
            }
 }
