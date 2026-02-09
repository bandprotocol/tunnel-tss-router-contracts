# Hardhat Deployment Scripts

This directory contains Hardhat-based deployment scripts as an alternative to Foundry/Forge.

## Setup

1. **Install Dependencies:**
   ```bash
   npm install
   ```

2. **Compile Contracts:**
   ```bash
   npx hardhat compile
   ```

## Deployment Scripts

### 1. Deploy Tunnel Router

Use `deploy_tunnel_router_hardhat.sh` to deploy the tunnel router infrastructure.

**What it deploys:**
- TssVerifier
- Vault (upgradeable proxy)
- TunnelRouter (either PriorityFeeTunnelRouter or GasPriceTunnelRouter, upgradeable proxy)

**Required Environment Variables:**
- `PRIVATE_KEY` - Your deployer private key
- `RPC_URL` - Target chain RPC URL
- `TARGET_CHAIN_ID` - Target chain identifier
- `BANDCHAIN_RPC_URL` - BandChain RPC URL
- `RELAYER_ADDR` - Comma-separated relayer addresses
- `OPERATOR_ADDRESS` - Operator address for gas fee updates
- `GAS_TYPE` - Either "legacy" or "eip1559"
- `REFUNDABLE` - "true" or "false"
- `TRANSITION_PERIOD` - Transition period in seconds

**Usage:**
```bash
export PRIVATE_KEY=your_private_key_here
./deploy_tunnel_router_hardhat.sh
```

### 2. Deploy Tunnel Consumer

Use `deploy_tunnel_consumer_hardhat.sh` to deploy packet consumer contracts.

**What it deploys:**
- PacketConsumer or PacketConsumerTick (depending on ENCODER_TYPE)
- PacketConsumerProxy

**Required Environment Variables:**
- `PRIVATE_KEY` - Your deployer private key
- `TUNNEL_ROUTER` - Address of the deployed tunnel router
- `RPC_URL` - Target chain RPC URL
- `TARGET_CHAIN_ID` - Target chain identifier
- `ENCODER_TYPE` - "tick" or "fixed_point"
- `BANDCHAIN_RPC_URL` - BandChain RPC URL
- `WALLET_NAME` - BandChain wallet name
- `OPERATOR_ADDRESS` - Operator address for tunnel activation

**Usage:**
```bash
export PRIVATE_KEY=your_private_key_here
export TUNNEL_ROUTER=0x... # From tunnel router deployment
./deploy_tunnel_consumer_hardhat.sh
```

## Hardhat Scripts

The JavaScript deployment scripts are located in `scripts-hardhat/`:

- **deployTunnelRouter.js** - Deploys TssVerifier, Vault, and TunnelRouter
- **deployPacketConsumer.js** - Deploys PacketConsumer
- **deployPacketConsumerTick.js** - Deploys PacketConsumerTick
- **deployPacketConsumerProxy.js** - Deploys PacketConsumerProxy

You can also run these scripts directly with:
```bash
npx hardhat run scripts-hardhat/{script-name}.js --network {network-name}
```

## Network Configuration

To use different networks, update `hardhat.config.js` to add network configurations:

```javascript
module.exports = {
  solidity: "0.8.23",
  networks: {
    meter_testnet: {
      url: "https://rpctest.meter.io",
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
```

Then run scripts with:
```bash
npx hardhat run scripts-hardhat/deployTunnelRouter.js --network meter_testnet
```

## Notes

- The scripts still use `cast` commands for contract interactions after deployment (granting roles, sending ETH, etc.)
- All deployment scripts output addresses for use in subsequent steps
- Make sure to set proper environment variables before running scripts
- The scripts include sleep intervals between transactions to ensure proper sequencing
