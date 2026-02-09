const { ethers } = require("hardhat");

async function main() {
  const packetConsumerAddr = process.env.PACKET_CONSUMER;
  
  if (!packetConsumerAddr) {
    throw new Error("PACKET_CONSUMER environment variable is not set");
  }

  const [signer] = await ethers.getSigners();
  const signerAddress = await signer.getAddress();

  console.log("Deploying PacketConsumerProxy...");
  const PacketConsumerProxy = await ethers.getContractFactory("PacketConsumerProxy");
  const packetConsumerProxy = await PacketConsumerProxy.deploy(packetConsumerAddr, signerAddress);
  await packetConsumerProxy.waitForDeployment();
  
  const packetConsumerProxyAddress = await packetConsumerProxy.getAddress();
  console.log("PacketConsumerProxy deployed at:", packetConsumerProxyAddress);

  return { packetConsumerProxy: packetConsumerProxyAddress };
}

if (require.main === module) {
  main()
    .then((addresses) => {
      console.log("\n=== Deployment Summary ===");
      console.log("PacketConsumerProxy:", addresses.packetConsumerProxy);
      process.exit(0);
    })
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = main;
