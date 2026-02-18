const { ethers, upgrades } = require("hardhat");

// Helper function to parse values with units (e.g., "1wei", "1gwei", "1ether")
function parseValue(value) {
  if (!value) return "0";
  
  const match = value.match(/^(\d+\.?\d*)(wei|gwei|ether)?$/);
  if (!match) return value;
  
  const [, amount, unit] = match;
  if (!unit || unit === "wei") {
    return amount;
  }
  return ethers.parseUnits(amount, unit).toString();
}

async function main() {
  // Get environment variables
  const transitionPeriod = process.env.TRANSITION_PERIOD;
  const transitionOriginatorHash = process.env.TRANSITION_ORIGINATOR_HASH;
  const tssParity = process.env.TSS_PARITY;
  const tssPublicKey = process.env.TSS_PUBLIC_KEY;
  const gasType = process.env.GAS_TYPE || "legacy";
  const priorityFeeRaw = process.env.PRIORITY_FEE || "1";
  const priorityFee = parseValue(priorityFeeRaw);
  const sourceChainId = process.env.SOURCE_CHAIN_ID;
  const targetChainId = process.env.TARGET_CHAIN_ID;
  const refundable = process.env.REFUNDABLE === "true";

  if (!transitionPeriod || !transitionOriginatorHash || !tssParity || !tssPublicKey) {
    throw new Error("Missing required environment variables");
  }
  if (!sourceChainId || !targetChainId) {
    throw new Error("Missing SOURCE_CHAIN_ID or TARGET_CHAIN_ID");
  }

  console.log("Deploying TunnelRouter contracts...");

  // Get signer
  const [signer] = await ethers.getSigners();
  const signerAddress = await signer.getAddress();

  // Deploy TssVerifier
  console.log("Deploying TssVerifier...");
  const TssVerifier = await ethers.getContractFactory("TssVerifier");
  const tssVerifier = await TssVerifier.deploy(
    transitionPeriod,
    transitionOriginatorHash,
    signerAddress
  );
  await tssVerifier.waitForDeployment();
  const tssVerifierAddress = await tssVerifier.getAddress();
  console.log("TssVerifier deployed at:", tssVerifierAddress);

  // Add TSS public key
  console.log("Adding TSS public key...");
  const tx = await tssVerifier.addPubKeyByOwner(0, tssParity, tssPublicKey);
  await tx.wait();

  // Deploy Vault proxy
  console.log("Deploying Vault...");
  const Vault = await ethers.getContractFactory("Vault");
  const vaultProxy = await upgrades.deployProxy(
    Vault,
    [signerAddress, ethers.ZeroAddress],
    { kind: "transparent" }
  );
  await vaultProxy.waitForDeployment();
  const vaultProxyAddress = await vaultProxy.getAddress();
  const vaultImplAddress = await upgrades.erc1967.getImplementationAddress(vaultProxyAddress);
  const vaultAdminAddress = await upgrades.erc1967.getAdminAddress(vaultProxyAddress);
  
  console.log("Vault Proxy deployed at:", vaultProxyAddress);
  console.log("Vault Implementation deployed at:", vaultImplAddress);
  console.log("Vault Admin deployed at:", vaultAdminAddress);

  // Deploy TunnelRouter based on gas type
  let tunnelRouterProxy;
  let tunnelRouterType;
  
  const sourceChainIdHash = ethers.keccak256(ethers.toUtf8Bytes(sourceChainId));
  const targetChainIdHash = ethers.keccak256(ethers.toUtf8Bytes(targetChainId));
  const constantValue = "17369806436495577561272982365083344973322337688717046180703435";

  if (gasType === "eip1559") {
    console.log("Deploying PriorityFeeTunnelRouter...");
    const PriorityFeeTunnelRouter = await ethers.getContractFactory("PriorityFeeTunnelRouter");
    tunnelRouterProxy = await upgrades.deployProxy(
      PriorityFeeTunnelRouter,
      [
        tssVerifierAddress,
        vaultProxyAddress,
        constantValue,
        4000,
        300000,
        priorityFee,
        sourceChainIdHash,
        targetChainIdHash,
        refundable
      ],
      { kind: "transparent" }
    );
    tunnelRouterType = "PriorityFee";
  } else {
    console.log("Deploying GasPriceTunnelRouter...");
    const GasPriceTunnelRouter = await ethers.getContractFactory("GasPriceTunnelRouter");
    const gasPriceRaw = process.env.GAS_PRICE || "1gwei";
    const gasPrice = parseValue(gasPriceRaw);
    tunnelRouterProxy = await upgrades.deployProxy(
      GasPriceTunnelRouter,
      [
        tssVerifierAddress,
        vaultProxyAddress,
        constantValue,
        4000,
        300000,
        gasPrice,
        sourceChainIdHash,
        targetChainIdHash,
        refundable
      ],
      { kind: "transparent" }
    );
    tunnelRouterType = "GasPrice";
  }

  await tunnelRouterProxy.waitForDeployment();
  const tunnelRouterProxyAddress = await tunnelRouterProxy.getAddress();
  const tunnelRouterImplAddress = await upgrades.erc1967.getImplementationAddress(tunnelRouterProxyAddress);
  const tunnelRouterAdminAddress = await upgrades.erc1967.getAdminAddress(tunnelRouterProxyAddress);

  console.log("TunnelRouter type:", tunnelRouterType);
  console.log("TunnelRouter Proxy deployed at:", tunnelRouterProxyAddress);
  console.log("TunnelRouter Implementation deployed at:", tunnelRouterImplAddress);
  console.log("TunnelRouter Admin deployed at:", tunnelRouterAdminAddress);

  // Set tunnel router in vault
  console.log("Setting tunnel router in vault...");
  const setTunnelRouterTx = await vaultProxy.setTunnelRouter(tunnelRouterProxyAddress);
  await setTunnelRouterTx.wait();

  // Return deployed addresses
  return {
    tssVerifier: tssVerifierAddress,
    vaultProxy: vaultProxyAddress,
    vaultImpl: vaultImplAddress,
    vaultAdmin: vaultAdminAddress,
    tunnelRouterProxy: tunnelRouterProxyAddress,
    tunnelRouterImpl: tunnelRouterImplAddress,
    tunnelRouterAdmin: tunnelRouterAdminAddress,
    tunnelRouterType
  };
}

// Execute deployment
if (require.main === module) {
  main()
    .then((addresses) => {
      console.log("\n=== Deployment Summary ===");
      console.log("TssVerifier:", addresses.tssVerifier);
      console.log("Vault Proxy:", addresses.vaultProxy);
      console.log("Vault Implementation:", addresses.vaultImpl);
      console.log("Vault Admin:", addresses.vaultAdmin);
      console.log("TunnelRouter type:", addresses.tunnelRouterType);
      console.log("TunnelRouter Proxy:", addresses.tunnelRouterProxy);
      console.log("TunnelRouter Implementation:", addresses.tunnelRouterImpl);
      console.log("TunnelRouter Admin:", addresses.tunnelRouterAdmin);
      process.exit(0);
    })
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = main;
