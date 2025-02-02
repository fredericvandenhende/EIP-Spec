const fs = require('fs');
require("babel-register");
 require("babel-polyfill");
module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 9545,
      network_id: "*"
    },
    coverage: {
      host: "localhost",
      network_id: "*",
      port: 9545,         // <-- If you change this, also set the port option in .solcover.js.
      gas: 0xfffffffffff, // <-- Use this high gas value
      gasPrice: 0x01      // <-- Use this low gas price
    }
  },
  rpc: {
    host: 'localhost',
    post: 8080
  },
  mocha: {
    enableTimeouts: false
  },
  compilers: {
    solc: {
      version: "0.6.0"
    }
  }
};
