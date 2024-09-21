// SPDX-License-Identifier: none
pragma solidity ^0.8.19;

//import {AccessControl} from './AccessControl.sol';

import 'hardhat/console.sol';

interface IAuction {
    function isClosed(uint32 lotId) external view returns (bool);
}

contract BidToken {
    struct Lock {
        uint32 lotId;
        uint128 amount;
    }

    IAuction public immutable auction;

    string public name = 'BiddingToken';
    string public symbol = 'BDT';
    uint8 public decimals = 18;

    mapping(address => uint128) private balances;
    mapping(address => Lock[]) private locks;

    constructor() {
        auction = IAuction(msg.sender);
    }

    modifier onlyAuction() {
        require(msg.sender == address(auction), "Not hub");
        _;
    }
 
    function data(address account) public view onlyAuction returns (uint128 balance, uint128 locked, Lock[] memory lotsList) {
        balance = balances[account];
        (locked, lotsList) = _locked(account);        
    }
    
    function mint(address to, uint128 amount) public onlyAuction {
        _update(to);
        unchecked {
            balances[to] += amount;
        }
    }

    error InsufficientBalance();
    error MaxAuctions();

    function burn(address from, uint128 amount) public onlyAuction {
        uint128 locked = _update(from);

        if (balances[from] - locked < amount) revert InsufficientBalance();
        
        unchecked {
            balances[from] -= amount;
        }
    }

    function transfer(address from, address to, uint128 amount) public onlyAuction {        
        uint128 locked = _update(from);

        if (balances[from] - locked < amount) revert InsufficientBalance();
        unchecked {
            balances[from] -= amount;           
            balances[to] += amount;
        }
    }

    // lock tokens for lot
    function lock(address account, uint32 lotId, uint128 amount) public onlyAuction {       
        if (amount == 0) return;
        (uint128 totalLocked, ) = _locked(account);

        bool auctionFound;
        for (uint8 i = 0; i < locks[account].length; i++) {
            if (locks[account][i].lotId == lotId) {
                auctionFound = true;
                uint128 locked = locks[account][i].amount;
                if (amount > locked) {
                    if (amount > balances[account] - (totalLocked - locked)) revert InsufficientBalance();
                    locks[account][i].amount = amount;
                }
                break;
            }
        }
        
        if (!auctionFound) {
            if (locks[account].length == 256) revert MaxAuctions();
            if (amount > balances[account] - totalLocked) revert InsufficientBalance();

            locks[account].push(Lock({
                lotId: lotId, 
                amount: amount
            }));
        }
    }
      
    // --------------------------------------------------------------
    
    function _update(address account) internal returns (uint128 locked) {
        uint8 idx = 0;
        uint256 length = locks[account].length;
        while (true) {
            if (length == 0 || idx >= length) break; // Break if there are no locks or all locks have been checked
            Lock memory lock_ = locks[account][idx];
            
            if (auction.isClosed(lock_.lotId)) {
                locks[account][idx] = locks[account][length - 1]; // Swap the current lock with the last one and remove the last one
                locks[account].pop(); // Decrease the length as one lock is removed
                length--;
            } else {
                locked += lock_.amount; // Add the amount of the unlocked lock to the total unlocked amount
                idx++; // Move to the next lock if the current one is not ready to be unlocked
            }
        }
    }

    function _locked(address account) internal view returns (uint128 locked, Lock[] memory locksList) {
        locksList = new Lock[](locks[account].length);
        for (uint8 i = 0; i < locks[account].length; i++) {
            Lock memory lock_ = locks[account][i];
            if (!auction.isClosed(lock_.lotId)) {
                locksList[i] = lock_;
                locked += lock_.amount;
            } 
        }
    }
}
