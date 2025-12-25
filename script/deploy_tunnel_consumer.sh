#!/bin/bash

set -e

# ================================================
# Environment variables; EDIT THIS
# ================================================

# Destination Chain
RPC_URL=
TARGET_CHAIN_ID=
export TUNNEL_ROUTER=
VAULT_BALANCE=
OPERATOR_ADDRESS=

# Bandchain
BANDCHAIN_RPC_URL=https://rpc.laozi3.bandchain.org/
WALLET_NAME=
BANDCHAIN_KEYRING_BACKEND=
PRICE_INTERVAL=
PRICE_DEVIATION_JSON_FILE=
FEE_PAYER_BALANCE=

CHAIN_ID=$(bandd status --node $BANDCHAIN_RPC_URL --output json | jq -r '.node_info.network')

# ================================================
# Setup consumer
# ================================================

echo "========== Cleaning and Building contracts =========="
forge clean && forge build --optimize true --optimizer-runs 200

echo "========== Deploying PacketConsumer contract =========="
MSG=$(forge script script/DeployPacketConsumer.s.sol:Executor --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --optimize true --optimizer-runs 200)
sleep 2
export PACKET_CONSUMER=$( echo "$MSG" | grep "PacketConsumer deployed at:" | awk '{print $4}' | xargs)

echo "========== Deploying PacketConsumerProxy contract =========="
MSG=$(forge script script/DeployPacketConsumerProxy.s.sol:Executor --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --optimize true --optimizer-runs 200)
sleep 2
PACKET_CONSUMER_PROXY=$( echo "$MSG" | grep "PacketConsumerProxy deployed at:" | awk '{print $4}' | xargs)

echo "================================================"
echo "PacketConsumer deployed at: $PACKET_CONSUMER" 
echo "PacketConsumerProxy deployed at: $PACKET_CONSUMER_PROXY"
echo "================================================"

# ================================================
# Setup tunnel on Bandchain
# ================================================

echo "========== Creating tunnel on BandChain =========="
bandd tx tunnel create-tunnel tss \
    $TARGET_CHAIN_ID $PACKET_CONSUMER 1 0uband $PRICE_INTERVAL $PRICE_DEVIATION_JSON_FILE \
    --from $WALLET_NAME --keyring-backend $BANDCHAIN_KEYRING_BACKEND --gas-prices 0.0025uband \
    -y --chain-id $CHAIN_ID --node $BANDCHAIN_RPC_URL

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
cast send $PACKET_CONSUMER "grantTunnelActivatorRole(address[])" "[$OPERATOR_ADDRESS]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
sleep 2

# ================================================
# Activate tunnel on target chain
# ================================================

echo "========== Activating tunnel $TUNNEL_ID on target chain via PacketConsumer =========="
cast send $PACKET_CONSUMER "activate(uint64,uint64)" $TUNNEL_ID 0 --value $VAULT_BALANCE --private-key $PRIVATE_KEY --rpc-url $RPC_URL

echo "================================================"
echo "Summary"
echo "Packet consumer contract: $PACKET_CONSUMER"
echo "Packet consumer Proxy contract: $PACKET_CONSUMER_PROXY"
echo "Tunnel ID: $TUNNEL_ID"
echo "Next step, deposit to the tunnel and activate it"
echo "================================================"
