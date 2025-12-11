# !/bin/bash

set -e

# ================================================
# Environment variables; EDIT THIS
# ================================================

RPC_URL=
PRIVATE_KEY=
TARGET_CHAIN_ID=
PRICE_DEVIATION_JSON_FILE=
PRICE_INTERVAL=
TUNNEL_ROUTER=
BANDCHAIN_URL=
WALLET_NAME=
BAND_KEYRING_BACKEND=
FEE_PAYER_BALANCE=
VAULT_BALANCE=

# ================================================
# Setup consumer
# ================================================

forge clean & forge build --optimize true --optimizer-runs 200

export TUNNEL_ROUTER=$TUNNEL_ROUTER
export PRIVATE_KEY=$PRIVATE_KEY
MSG=$(forge script script/DeployPacketConsumer.s.sol:Executor --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --optimize true --optimizer-runs 200)
PACKET_CONSUMER=$( echo "$MSG" | grep "PacketConsumer deployed at:" | awk '{print $4}' | xargs)

export PACKET_CONSUMER=$PACKET_CONSUMER
MSG=$(forge script script/DeployPacketConsumerProxy.s.sol:Executor --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY --optimize true --optimizer-runs 200)
PACKET_CONSUMER_PROXY=$( echo "$MSG" | grep "PacketConsumerProxy deployed at:" | awk '{print $4}' | xargs)

echo "================================================"
echo "PacketConsumer deployed at: $PACKET_CONSUMER" 
echo "PacketConsumerProxy deployed at: $PACKET_CONSUMER_PROXY"
echo "================================================"

# ================================================
# Setup tunnel on Bandchain
# ================================================

CHAIN_ID=$(bandd status --node $BANDCHAIN_URL --output json | jq -r '.node_info.network')

bandd tx tunnel create-tunnel tss \
    $TARGET_CHAIN_ID $PACKET_CONSUMER 1 1uband $PRICE_INTERVAL $PRICE_DEVIATION_JSON_FILE \
    --from $WALLET_NAME --keyring-backend $BAND_KEYRING_BACKEND --gas-prices 0.0025uband \
    -y --chain-id $CHAIN_ID --node $BANDCHAIN_URL

sleep 5

TUNNEL_ID=$(bandd q tunnel tunnels --page-count-total --page-limit 1 --output json --node $BANDCHAIN_URL | jq -r '.pagination.total')

echo "================================================"
echo "TUNNEL_ID: $TUNNEL_ID is created" 
echo "================================================"

# transfer token to fee payer
fee_payer=$(bandd q tunnel tunnel $TUNNEL_ID --node $BANDCHAIN_URL --output json | jq -r '.tunnel.fee_payer') 

bandd tx bank send $WALLET_NAME $fee_payer $FEE_PAYER_BALANCE \
    --from $WALLET_NAME --keyring-backend $BAND_KEYRING_BACKEND --gas-prices 0.0025uband \
     -y --chain-id $CHAIN_ID --node $BANDCHAIN_URL

sleep 5

# deposit to tunnel
bandd tx tunnel deposit-to-tunnel $TUNNEL_ID 500000000uband \
    --from $WALLET_NAME --keyring-backend $BAND_KEYRING_BACKEND \
    -y --chain-id $CHAIN_ID --gas-prices 0.0025uband --node $BANDCHAIN_URL

sleep 5

# ================================================
# Activate tunnel on band chain
# ================================================

bandd tx tunnel activate-tunnel $TUNNEL_ID \
    --from $WALLET_NAME --keyring-backend $BAND_KEYRING_BACKEND \
    --gas-prices 0.0025uband \
    -y --chain-id $CHAIN_ID --node $BANDCHAIN_URL
sleep 5

# ================================================
# Activate tunnel on target chain
# ================================================

cast send $PACKET_CONSUMER "activate(uint64,uint64)" $TUNNEL_ID 0 --value $VAULT_BALANCE --private-key $PRIVATE_KEY --rpc-url $RPC_URL

echo "================================================"
echo "Summary"
echo "Consumer contract: $PACKET_CONSUMER"
echo "Consumer Proxy contract: $PACKET_CONSUMER_PROXY"
echo "Tunnel ID: $TUNNEL_ID"
echo "================================================"