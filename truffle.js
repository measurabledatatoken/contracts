// Allows us to use ES6 in our migrations and tests.
require('babel-register');
const HDWalletProvider = require('truffle-hdwallet-provider');
const credentials = require('./credentials');

module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // Match any network id
      gas: 4712388,
      // gasPrice: 20000000000
    },
    ropsten: {
      host: 'localhost',
      port: 8546,
      network_id: '3'
    },
    ropstenInfura: {
      provider: new HDWalletProvider(credentials.ropstenMnemonic, 'https://ropsten.infura.io/' + credentials.infuraToken),
      network_id: 3,
      gas: 712388
    },
    mainnetInfura: {
      provider: new HDWalletProvider(credentials.mainnetMnemonic, 'https://mainnet.infura.io/' + credentials.infuraToken, 4),
      network_id: 1,
      gas: 712388
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};
