#!/bin/bash

set -e

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# ================================================
# Environment variables; EDIT THIS
# ================================================

# NOTE: Set VAULT_BALANCE=0 if the tunnel is not refundable.
#       For non-refundable tunnels (router REFUNDABLE=false), funding is not needed.

# Destination Chain
export RPC_URL=
export TARGET_CHAIN_ID=
export TUNNEL_ROUTER=
export VAULT_BALANCE=1ether
export OPERATOR_ADDRESS=
export GAS_TYPE=eip1559

# Bandchain
export BANDCHAIN_RPC_URL=https://rpc.laozi3.bandchain.org/
export WALLET_NAME=
export BANDCHAIN_KEYRING_BACKEND=
export PRICE_INTERVAL=
export PRICE_DEVIATION_JSON_FILE=
export FEE_PAYER_BALANCE=
export ENCODER_TYPE=

export CHAIN_ID=$(bandd status --node $BANDCHAIN_RPC_URL --output json | jq -r '.node_info.network')

# Set gas flags for cast commands
if [ "$GAS_TYPE" == "legacy" ]; then
    GAS_FLAG="--legacy"
else
    GAS_FLAG=""
fi

# ================================================
# Summary
# ================================================

# trap: On any error or script exit, always print summary section
print_summary() {
    echo "================================================"
    echo "Summary"
    echo "Bandchain source chain ID: $CHAIN_ID (rpc url: $BANDCHAIN_RPC_URL)"
    echo "Target chain ID: $TARGET_CHAIN_ID (rpc url: $RPC_URL)"
    echo "Deployed contracts:"
    echo "Packet consumer type: $PACKET_CONSUMER_TYPE"
    echo "Packet consumer contract: $PACKET_CONSUMER"
    echo "Packet consumer proxy contract: $PACKET_CONSUMER_PROXY"
    echo "Band Tunnel"
    echo "Tunnel ID: $TUNNEL_ID"
    echo "Tunnel fee payer: $FEE_PAYER"
    echo "Next step, deposit to the tunnel and activate it"
    echo "================================================"
}
trap print_summary EXIT

# ================================================
# Setup consumer
# ================================================

echo "========== Compiling contracts with Hardhat =========="
npx hardhat compile --force

if [ "$ENCODER_TYPE" == "tick" ]; then
    # Extract signal_ids from price deviation JSON file
    echo "========== Extracting signal_ids from $PRICE_DEVIATION_JSON_FILE =========="
    SIGNAL_IDS=$(jq -r '.signal_deviations[].signal_id' "$PRICE_DEVIATION_JSON_FILE" | paste -sd, -)
    echo "Signal IDs: $SIGNAL_IDS"
    echo "================================================"

    echo "========== Deploying PacketConsumerTick contract =========="
    DEPLOY_OUTPUT=$(npx hardhat run scripts-hardhat/deployPacketConsumerTick.js --network localhost)
    echo "$DEPLOY_OUTPUT"
    export PACKET_CONSUMER=$(echo "$DEPLOY_OUTPUT" | grep "PacketConsumerTick:" | awk '{print $2}')
    PACKET_CONSUMER_TYPE=tick

    echo "========== Listing signal IDs on PacketConsumerTick =========="
    cast send $PACKET_CONSUMER "listing(string[])" "[$SIGNAL_IDS]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL $GAS_FLAG 2>&1 | grep -E "(blockHash|transactionHash|Error: \()" || true
    sleep 5
else
    echo "========== Deploying PacketConsumer contract =========="
    DEPLOY_OUTPUT=$(npx hardhat run scripts-hardhat/deployPacketConsumer.js --network localhost)
    echo "$DEPLOY_OUTPUT"
    export PACKET_CONSUMER=$(echo "$DEPLOY_OUTPUT" | grep "PacketConsumer:" | awk '{print $2}')
    PACKET_CONSUMER_TYPE=fixed_point
fi

echo "========== Deploying PacketConsumerProxy contract =========="
PROXY_OUTPUT=$(npx hardhat run scripts-hardhat/deployPacketConsumerProxy.js --network localhost 2>&1)
echo "$PROXY_OUTPUT"
PACKET_CONSUMER_PROXY=$(echo "$PROXY_OUTPUT" | grep "PacketConsumerProxy:" | awk '{print $2}')

echo "================================================"
echo "PacketConsumer deployed at: $PACKET_CONSUMER" 
echo "PacketConsumerProxy deployed at: $PACKET_CONSUMER_PROXY"
echo "================================================"

# ================================================
# Setup tunnel on Bandchain
# ================================================

echo "========== Creating tunnel on BandChain =========="
if [ "$ENCODER_TYPE" == "tick" ]; then
    bandd tx tunnel create-tunnel tss \
        $TARGET_CHAIN_ID $PACKET_CONSUMER 2 0uband $PRICE_INTERVAL $PRICE_DEVIATION_JSON_FILE \
        --from $WALLET_NAME --keyring-backend $BANDCHAIN_KEYRING_BACKEND --gas-prices 0.0025uband \
        -y --chain-id $CHAIN_ID --node $BANDCHAIN_RPC_URL
else
    bandd tx tunnel create-tunnel tss \
    $TARGET_CHAIN_ID $PACKET_CONSUMER 1 0uband $PRICE_INTERVAL $PRICE_DEVIATION_JSON_FILE \
    --from $WALLET_NAME --keyring-backend $BANDCHAIN_KEYRING_BACKEND --gas-prices 0.0025uband \
    -y --chain-id $CHAIN_ID --node $BANDCHAIN_RPC_URL
fi

sleep 5

echo "========== Querying TUNNEL_ID after creation =========="
TUNNEL_ID=$(bandd q tunnel tunnels --page-count-total --page-limit 1 --output json --node $BANDCHAIN_RPC_URL | jq -r '.pagination.total')

echo "================================================"
echo "TUNNEL_ID: $TUNNEL_ID is created" 
echo "================================================"

# transfer token to fee payer
echo "========== Querying tunnel fee payer address =========="
fee_payer=$(bandd q tunnel tunnel $TUNNEL_ID --node $BANDCHAIN_RPC_URL --output json | jq -r '.tunnel.fee_payer') 

echo "========== Transferring $FEE_PAYER_BALANCE to tunnel fee payer: $fee_payer =========="
bandd tx bank send $WALLET_NAME $fee_payer $FEE_PAYER_BALANCE \
    --from $WALLET_NAME --keyring-backend $BANDCHAIN_KEYRING_BACKEND --gas-prices 0.0025uband \
     -y --chain-id $CHAIN_ID --node $BANDCHAIN_RPC_URL

sleep 5

if [ -n "$OPERATOR_ADDRESS" ]; then
    echo "========== Granting Tunnel Activator role to operator =========="
    cast send $PACKET_CONSUMER "grantTunnelActivatorRole(address[])" "[$OPERATOR_ADDRESS]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL $GAS_FLAG 2>&1 | grep -E "(blockHash|transactionHash|Error: \()" || true
    sleep 5
else
    echo "========== Skipping Tunnel Activator role grant (OPERATOR_ADDRESS not set) =========="
fi

# ================================================
# Activate tunnel on target chain
# ================================================

echo "========== Activating tunnel $TUNNEL_ID on target chain via PacketConsumer =========="
cast send $PACKET_CONSUMER "activate(uint64,uint64)" $TUNNEL_ID 0 --value $VAULT_BALANCE --private-key $PRIVATE_KEY --rpc-url $RPC_URL $GAS_FLAG 2>&1 | grep -E "(blockHash|transactionHash|Error: \()" || true
