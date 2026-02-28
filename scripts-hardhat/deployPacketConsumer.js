const { ethers } = require("hardhat");

async function main() {
  const tunnelRouterAddr = process.env.TUNNEL_ROUTER;
  
  if (!tunnelRouterAddr) {
    throw new Error("TUNNEL_ROUTER environment variable is not set");
  }

  console.log("Deploying PacketConsumer...");
  const PacketConsumer = await ethers.getContractFactory("PacketConsumer");
  const packetConsumer = await PacketConsumer.deploy(tunnelRouterAddr);
  await packetConsumer.waitForDeployment();
  
  const packetConsumerAddress = await packetConsumer.getAddress();
  console.log("PacketConsumer deployed at:", packetConsumerAddress);

  return { packetConsumer: packetConsumerAddress };
}

if (require.main === module) {
  main()
    .then((addresses) => {
      console.log("\n=== Deployment Summary ===");
      console.log("PacketConsumer:", addresses.packetConsumer);
      process.exit(0);
    })
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = main;
