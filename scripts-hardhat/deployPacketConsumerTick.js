const { ethers } = require("hardhat");

async function main() {
  const tunnelRouterAddr = process.env.TUNNEL_ROUTER;
  const useZkSync = process.env.USE_ZKSYNC === "true";
  
  if (!tunnelRouterAddr) {
    throw new Error("TUNNEL_ROUTER environment variable is not set");
  }

  console.log("Deploying PacketConsumerTick...");
  if (useZkSync) {
    console.log("Using zkSync deployment mode");
  }
  const PacketConsumerTick = await ethers.getContractFactory("PacketConsumerTick");
  const packetConsumerTick = await PacketConsumerTick.deploy(tunnelRouterAddr);
  await packetConsumerTick.waitForDeployment();
  
  const packetConsumerTickAddress = await packetConsumerTick.getAddress();
  console.log("PacketConsumerTick deployed at:", packetConsumerTickAddress);

  return { packetConsumerTick: packetConsumerTickAddress };
}

if (require.main === module) {
  main()
    .then((addresses) => {
      console.log("\n=== Deployment Summary ===");
      console.log("PacketConsumerTick:", addresses.packetConsumerTick);
      process.exit(0);
    })
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = main;
