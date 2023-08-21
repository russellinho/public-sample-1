/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require ("@nomiclabs/hardhat-waffle");
require ("@nomiclabs/hardhat-ethers");
require ("@openzeppelin/hardhat-upgrades");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [ 
      {
        version: "0.8.10"
      },
      {
        version: "0.7.6"
      }
    ]
  },
  networks: {
    fuji: {
      url: 'https://api.avax-test.network/ext/bc/C/rpc',
      // gasPrice: 30000000000,
      chainId: 43113,
      accounts: ['']
    },
    // mainnet: {
    //   url: 'https://api.avax.network/ext/bc/C/rpc',
    //   chainId: 43114,
    //   accounts: ['']
    // },
    testnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      chainId: 97,
      accounts: ['']
    },
    mainnet: {
      url: 'https://polygon-rpc.com',
      chainId: 137,
      accounts: ['']
    },
  }
}
