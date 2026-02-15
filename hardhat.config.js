require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");

// Conditionally load zkSync plugin only if USE_ZKSYNC is true
if (process.env.USE_ZKSYNC === "true") {
  require("@matterlabs/hardhat-zksync");
  require("@matterlabs/hardhat-zksync-solc");
}

/** @type import('hardhat/config').HardhatUserConfig */
const config = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      evmVersion: "shanghai",
      viaIR: false,
    },
  },
  paths: {
    sources: "./src",
    tests: "./test",
    cache: "./cache",
    artifacts: "./out"
  },
  networks: {
    localhost: {
      url: process.env.RPC_URL,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    }
  }
};

// Add zkSync-specific config only if USE_ZKSYNC is true
if (process.env.USE_ZKSYNC === "true") {
  // Set zkSync artifacts path
  config.paths.artifacts = "./out-zk";
  
  config.zksolc = {
    version: "1.5.15",
    settings: {
      optimizer: {
        enabled: true,
        mode: "3"
      },
      codegen: "evmla",
    },
    compilerSource: "binary",
  };
  
  config.networks.localhost.zksync = true;
  // For zkSync L2 networks, ethNetwork specifies the L1 network
  config.networks.localhost.ethNetwork = process.env.ETH_NETWORK || "sepolia";
}

module.exports = config;
