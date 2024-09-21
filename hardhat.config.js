require('dotenv').config({path:__dirname+'/.env'})
//require('@oasisprotocol/sapphire-hardhat');
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-chai-matchers");
require('solidity-coverage')

module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      { version: "0.8.19", settings: { optimizer: { enabled: true, runs: 5 } } },     
      { version: "0.7.6", settings: { optimizer: { enabled: true, runs: 5 } } },     
    ],
  },
 
  networks: {
    hardhat: {
      gasPrice: 'auto',
      throwOnTransactionFailures: true,
      throwOnCallFailures: true,
      allowUnlimitedContractSize: true,      
      loggingEnabled: false,     
      accounts: { 
        mnemonic: 'test test test test test test test test test test test junk', 
        accountsBalance: "1000000000000000000000000000",
      },
      
    },
    sapphire_local: { // docker run -it -p8545:8545 -p8546:8546 ghcr.io/oasisprotocol/sapphire-localnet -test-mnemonic
      url: "http://localhost:8545",
      chainId: 23293,
      gasPrice: 'auto',
      accounts: { mnemonic: 'test test test test test test test test test test test junk' },     
    },

    sapphire_vps: { 
      url: "https://nodesap.appdev.pp.ua",
      chainId: 23293,
      gasPrice: 'auto',
      accounts: { mnemonic: 'test test test test test test test test test test test junk' },     
    },
    sapphireTestnet: {
      url: "https://testnet.sapphire.oasis.io",
      chainId: 23295,
      gasPrice: 'auto',
      accounts: { mnemonic: 'test test test test test test test test test test test junk' },   
    },
    local2: { 
      url: 'http://127.0.0.1:31225',
      chainId: 225,
      gasPrice: 'auto',
      accounts: { mnemonic: 'test test test test test test test test test test test junk' },
    },
  },
  
  etherscan: {
    apiKey: {
       
    }
  },

};
