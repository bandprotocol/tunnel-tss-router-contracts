#!/bin/bash

set -e

# ================================================
# Environment variables; EDIT THIS
# ================================================

# NOTE: Set VAULT_BALANCE=0 if the tunnel is not refundable.
#       For non-refundable tunnels (router REFUNDABLE=false), funding is not needed.

# Destination Chain
RPC_URL=
TARGET_CHAIN_ID=
export TUNNEL_ROUTER=
VAULT_BALANCE=
OPERATOR_ADDRESS=
GAS_TYPE=eip1559

# Bandchain
BANDCHAIN_RPC_URL=https://rpc.laozi3.bandchain.org/
WALLET_NAME=
BANDCHAIN_KEYRING_BACKEND=
PRICE_INTERVAL=
PRICE_DEVIATION_JSON_FILE=
FEE_PAYER_BALANCE=
ENCODER_TYPE=

CHAIN_ID=$(bandd status --node $BANDCHAIN_RPC_URL --output json | jq -r '.node_info.network')

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
    echo "Tunnel fee payer: $fee_payer"
    echo "Next step, deposit to the tunnel and activate it"
    echo "================================================"
}
trap print_summary EXIT

# ================================================
# Setup consumer
# ================================================

echo "========== Cleaning and Building contracts =========="
forge clean && forge build --optimize true --optimizer-runs 200

if [ "$ENCODER_TYPE" == "tick" ]; then
    # Extract signal_ids from price deviation JSON file
    echo "========== Extracting signal_ids from $PRICE_DEVIATION_JSON_FILE =========="
    SIGNAL_IDS=$(jq -r '.signal_deviations[].signal_id' "$PRICE_DEVIATION_JSON_FILE" | paste -sd, -)
    echo "Signal IDs: $SIGNAL_IDS"
    echo "================================================"

    echo "========== Deploying PacketConsumerTick contract =========="
    if [ "$GAS_TYPE" == "legacy" ]; then
        MSG=$(forge script script/DeployPacketConsumerTick.s.sol:Executor --rpc-url $RPC_URL --slow --broadcast --private-key $PRIVATE_KEY --optimize true --optimizer-runs 200 --legacy)
    else
        MSG=$(forge script script/DeployPacketConsumerTick.s.sol:Executor --rpc-url $RPC_URL --slow --broadcast --private-key $PRIVATE_KEY --optimize true --optimizer-runs 200)
    fi
    export PACKET_CONSUMER=$( echo "$MSG" | grep "PacketConsumerTick deployed at:" | awk '{print $4}' | xargs)
    PACKET_CONSUMER_TYPE=tick

    echo "========== Listing signal IDs on PacketConsumerTick =========="
    if [ "$GAS_TYPE" == "legacy" ]; then
        cast send $PACKET_CONSUMER "listing(string[])" "[$SIGNAL_IDS]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
    else
        cast send $PACKET_CONSUMER "listing(string[])" "[$SIGNAL_IDS]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
    fi
    sleep 5
else
    echo "========== Deploying PacketConsumer contract =========="
    if [ "$GAS_TYPE" == "legacy" ]; then
        MSG=$(forge script script/DeployPacketConsumer.s.sol:Executor --rpc-url $RPC_URL --slow --broadcast --private-key $PRIVATE_KEY --optimize true --optimizer-runs 200 --legacy)
    else
        MSG=$(forge script script/DeployPacketConsumer.s.sol:Executor --rpc-url $RPC_URL --slow --broadcast --private-key $PRIVATE_KEY --optimize true --optimizer-runs 200)
    fi
    export PACKET_CONSUMER=$( echo "$MSG" | grep "PacketConsumer deployed at:" | awk '{print $4}' | xargs)
    PACKET_CONSUMER_TYPE=fixed_point
fi

echo "========== Deploying PacketConsumerProxy contract =========="
if [ "$GAS_TYPE" == "legacy" ]; then
    MSG=$(forge script script/DeployPacketConsumerProxy.s.sol:Executor --rpc-url $RPC_URL --slow --broadcast --private-key $PRIVATE_KEY --optimize true --optimizer-runs 200 --legacy)
else
    MSG=$(forge script script/DeployPacketConsumerProxy.s.sol:Executor --rpc-url $RPC_URL --slow --broadcast --private-key $PRIVATE_KEY --optimize true --optimizer-runs 200)
fi
PACKET_CONSUMER_PROXY=$( echo "$MSG" | grep "PacketConsumerProxy deployed at:" | awk '{print $4}' | xargs)

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

echo "========== Granting Tunnel Activator role to operator =========="
if [ "$GAS_TYPE" == "legacy" ]; then
    cast send $PACKET_CONSUMER "grantTunnelActivatorRole(address[])" "[$OPERATOR_ADDRESS]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
else
    cast send $PACKET_CONSUMER "grantTunnelActivatorRole(address[])" "[$OPERATOR_ADDRESS]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
fi
sleep 5

# ================================================
# Activate tunnel on target chain
# ================================================

echo "========== Activating tunnel $TUNNEL_ID on target chain via PacketConsumer =========="
if [ "$GAS_TYPE" == "legacy" ]; then
    cast send $PACKET_CONSUMER "activate(uint64,uint64)" $TUNNEL_ID 0 --value $VAULT_BALANCE --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
else
    cast send $PACKET_CONSUMER "activate(uint64,uint64)" $TUNNEL_ID 0 --value $VAULT_BALANCE --private-key $PRIVATE_KEY --rpc-url $RPC_URL
fi
