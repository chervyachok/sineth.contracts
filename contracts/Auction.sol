// SPDX-License-Identifier: none
pragma solidity ^0.8.19;


import "@oasisprotocol/sapphire-contracts/contracts/EthereumUtils.sol";
import "@oasisprotocol/sapphire-contracts/contracts/Sapphire.sol";
import { BidToken } from "./BidToken.sol";

import "hardhat/console.sol";

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract Auction {   
    BidToken public immutable token;  

    uint32 public revealDuration = 1000;     
    uint32 public lotIdx = 0;
    uint16 public maxBids = 10000;
    uint16 public maxComputeBids = 500;
    uint16 private constant FEE_BASE = 100;
    uint8 public feePercent = 1;

    address public immutable serviceWallet;

    // dev purpose
    uint256 private chainId;
    uint256 private sapphireChainId = 23293;

    struct Lot {
        uint32 startTs;
        uint32 completeTs;    
        uint32 closeTs;  
        uint16 participants;
        uint16 bidded;  
        uint128 bidStep;
        uint16 highBid;
        bytes15 nonce;
        uint128 winBid;
        address creator;
        address winner;
        
    }
    mapping(uint32 => Lot) private lots;    
    mapping(uint32 => mapping(uint16 => address)) private bids;
    mapping(uint32 => mapping(address => bool)) public lotParticipants;
    mapping(uint32 => address[]) public participantsList;
   
    bytes private publicKey;
    bytes private privateKey;
    

    // --------------------- CONSTRUCT ---------------------    

    constructor (
        address serviceWallet_, 
        uint256 chainId_,
        uint32 revealDuration_,
        uint16 maxBids_,
        uint8 feePercent_
        ) { 
        serviceWallet = serviceWallet_;
        token = new BidToken();

        revealDuration = revealDuration_;
        maxBids = maxBids_;
        feePercent = feePercent_;

        chainId = chainId_;
        if (chainId == sapphireChainId) {
            (publicKey, privateKey) = Sapphire.generateSigningKeyPair(Sapphire.SigningAlg.Secp256k1PrehashedKeccak256, Sapphire.randomBytes(32, ""));
        }        
    }
        
    function start(uint128 bidStep, uint32 duration) public {    
        //IERC721(asset).transferFrom(msg.sender, address(this), assetId);
        lotIdx ++; 
        lots[lotIdx] = Lot({
            creator: msg.sender,
            startTs: uint32(block.timestamp),
            completeTs: uint32(block.timestamp) + duration,
            closeTs: 0,
            winner: address(0),
            bidStep: bidStep,            
            highBid: 0,
            participants: 0,
            bidded: 0,
            nonce: bytes15(Sapphire.randomBytes(15, "")),
            winBid: 0
        });  

        emit Start(lotIdx); 
    }
    event Start(uint256 indexed lotId);

    function getLot(uint32 lotId) public view 
        returns (
            address creator,
            uint32 startTs, 
            uint32 completeTs, 
            uint32 closeTs,
            address winner, 
            uint128 bidStep, 
            uint16 participants, 
            uint16 bidded,
            uint128 winBid
        ) {
        Lot memory lot = lots[lotId];
        creator = lot.creator;
        startTs = lot.startTs;
        closeTs = lot.closeTs;
        completeTs = lot.completeTs;
        winner = lot.winner;
        bidStep = lot.bidStep;
        participants = lot.participants;
        bidded = lot.bidded;
        winBid = lot.winBid;
    }

    function getAccount() public view 
        returns (
            uint256 balance, 
            uint256 locked, 
            BidToken.Lock[] memory list
        ) {
        console.log('accountData', msg.sender);
        return token.data(msg.sender);
    }

    function getParticipants(uint32 lotId) public view returns (address[] memory) {
        return participantsList[lotId];       
    }

    function isClosed(uint32 lotId) public view returns (bool state) {
        state = lots[lotId].completeTs + revealDuration <= block.timestamp || lots[lotId].closeTs > 0;
        console.log('state', state);
        return state;
    }

    function deposit() public payable {
        token.mint(msg.sender, uint128(msg.value));
    }

    function withdraw(uint128 amount) public {
        token.burn(msg.sender, amount);
        (bool success, ) = msg.sender.call{ value: amount }('');
        require(success, "Eth send failed");
    }

    function sender() public view returns (address) {
        return msg.sender;
    }
        
    struct Bid {
        address account;
        uint32 lotId;
        uint16[] bids;
    }
    // if called without wrapper lotId is exposed but we still encrypt bid amounts for case if user not use provider wrapper
    function placeBids(uint32 lotId, uint16[] calldata bidIndexes) public {  
        Lot storage lot = lots[lotId];

        require(lot.completeTs >= block.timestamp, 'Auction completed');        
        
        uint16 highBid;
        uint128 fee;
        {
            for (uint16 i = 0; i < bidIndexes.length; i++) {
                uint16 bidIndex = bidIndexes[i];            
                //require(amount % lot.bidStep == 0, "Wrong bid step");                       
                address bidder = bids[lotId][bidIndex];
                if (bidder == address(0)) {
                    // no one placed bid yet so sender is first and bid unique, so we assign address of bidder to it
                    bids[lotId][bidIndex] = msg.sender;
                } else if (bidder != address(1) && bidder != msg.sender) {
                    // bid not unique anymore, so we assign address 1 as non unique marker
                    bids[lotId][bidIndex] = address(1);
                }

                uint128 bidAmount = bidIndex * lot.bidStep;
                if (highBid < bidIndex) highBid = bidIndex; // highest bid amount will be locked for user  

                fee += bidAmount * feePercent / FEE_BASE;  
            }    
        }           

        if (lot.highBid < highBid) lot.highBid = highBid;
        require(lot.highBid <= maxBids, 'Max bid amount cap');

        lot.bidded += 1;

        if (!lotParticipants[lotId][msg.sender]) {
            lotParticipants[lotId][msg.sender] = true;
            participantsList[lotId].push(msg.sender);
            lot.participants += 1;
            emit Join(lotId); 
        }

        emit Place(lotId); 
        uint128 lockAmount = highBid * lot.bidStep;
        console.log('lockAmount', lockAmount, fee);
        token.lock(msg.sender, lotId, lockAmount); 
        token.transfer(msg.sender, serviceWallet, fee);   
    }
    event Join(uint32 indexed lotId);
    event Place(uint32 indexed lotId);    

    struct UniquenessResult {  
        uint32 lotId;
        uint16 lastBid;  
        bool account;
        bool lot;        
    }

    function checkUniqueness(uint32 lotId, bytes memory prevResultData) public view returns (bytes memory newResultData, bool completed){
        Lot memory lot = lots[lotId];

        require(lot.participants > 0, "No participants");
        
        uint16 startBid;
        
        UniquenessResult memory newResult;
        UniquenessResult memory prevResult;
        {
            if (prevResultData.length > 1) {            
                if (chainId == sapphireChainId) {
                    bytes memory decrypted = Sapphire.decrypt(bytes32(privateKey), lot.nonce, prevResultData, "");
                    prevResult = abi.decode(decrypted, (UniquenessResult));   
                } else {
                    prevResult = abi.decode(prevResultData, (UniquenessResult)); 
                }
                require(prevResult.lotId == lotId, 'Wrong lot id');
                startBid = prevResult.lastBid + 1;
            } else {
                startBid = 1;
                prevResult.lotId = lotId;
            }    
        }
                
        uint16 bidsLeft = maxBids - startBid + 1;        
        uint16 lastBid = bidsLeft > maxComputeBids ?  startBid + maxComputeBids - 1 : maxBids;      
        console.log('---', startBid, lastBid, bidsLeft);

        uint32 lotId_ = lotId;
        for (uint16 currBid = startBid; currBid <= lastBid;) {
            address state = bids[lotId_][currBid];
            if (state > address(1)) {
                prevResult.lot = true;
                if (state == msg.sender) {
                    prevResult.account = true;
                }               
            }
            unchecked {
                currBid ++;  
            }
        }   
        
        newResult = prevResult;
        newResult.lastBid = lastBid;
        newResultData = abi.encode(newResult);

        completed = (lastBid == maxBids);
        
        if (chainId == sapphireChainId) {
            if (!completed) {
                newResultData = Sapphire.encrypt(bytes32(privateKey), lot.nonce, newResultData, "");
            }
        }         
    }
    
}