const { utils } = require("ethers");
const { ethers } = require("hardhat");
const { promises: { readFile, writeFile } } = require("fs");
const path = require('path')
const sapphire = require('@oasisprotocol/sapphire-paratime') 

// npx hardhat run --network hardhat scripts/exp.js
// npx hardhat run --network local2 scripts/exp.js
// npx hardhat run --network sapphire_local scripts/exp.js
// npx hardhat run --network sapphire_vps scripts/exp.js

const fileName = 'bcConfig_auction.json'
const filePath = path.join(__dirname, '../../../', fileName)
let bcConfig = {}

async function main() {  
    const chainId = Number(await network.provider.send('eth_chainId'));
    let deployer, serviceWallet, acc1, acc2, acc3, acc4, acc5, acc6 
    
    const signers = await ethers.getSigners();
    [ deployer, serviceWallet, acc1, acc2, acc3, acc4, acc5, acc6 ] = signers.map(s => chainId == 23293 ? sapphire.wrap(s) : s)
    
    try { bcConfig = JSON.parse((await readFile(filePath, 'utf-8')))  } catch (error) { }
    const startBlock = await ethers.provider.getBlockNumber();
    bcConfig = { chainId }
               
    
	console.log("--------------------------------DEPLOY----------------------------------", chainId) //, hre
    
    const revealDuration = 1000;
    const maxBids = 1000
    const feePercent = 1
    const AuctionLubExp = await ethers.getContractFactory("Auction", deployer);    
    let auction = await AuctionLubExp.deploy(
        serviceWallet.address, 
        chainId,
        revealDuration,
        maxBids,
        feePercent
    );
    await auction.deployed(); 
    console.log('auction', auction.address)

    bcConfig.auction = {
		address: auction.address,
        abi: auction.interface.format(),
        startBlock,
        config: {
            revealDuration,
            maxBids,
            feePercent,
            feeBase: 100,
        }
	}
    bcConfig.rpcUrl = network.config.url || network.config.forking?.url
    
    await writeFile(`../${fileName}`, JSON.stringify(bcConfig, null, 4));
}

main().then(() => process.exit(0)).catch((error) => { console.error(error); process.exit(1); });
