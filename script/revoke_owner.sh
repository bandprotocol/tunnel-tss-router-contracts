RPC_URL=

TUNNEL_ROUTER_ADDRESS=
PACKET_CONSUMER_ADDRESS=

FROM_ADDRESS=

ZKSYNC=false
GAS_TYPE=eip1559

# Note: Before running this script, export the following environment variables in your shell:
#       export CURRENT_OWNER_PRIVATE_KEY=<your_current_owner_private_key>

if [ "$GAS_TYPE" == "legacy" ]; then
    GAS_TYPE_FLAG=--legacy
else
    GAS_TYPE_FLAG=
fi

if [ "$ZKSYNC" == "true" ]; then
    ZKSYNC_BUILD_FLAG="--zksync --suppress-errors sendtransfer"
    ZKSYNC_FLAG="--zksync"
else
    ZKSYNC_BUILD_FLAG=""
    ZKSYNC_FLAG=""
fi

ADMIN_ROLE=$(cast to-bytes32 0x00)

# Revoke all roles of the TunnelRouter contract
cast send $TUNNEL_ROUTER_ADDRESS "revokeGasFeeUpdater(address[])" "[$FROM_ADDRESS]" --private-key $CURRENT_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG
cast send $TUNNEL_ROUTER_ADDRESS "revokeRole(bytes32, address)" $ADMIN_ROLE $FROM_ADDRESS --private-key $CURRENT_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG

# Revoke all roles of the PacketConsumer contract
cast send $PACKET_CONSUMER_ADDRESS "revokeTunnelActivatorRole(address[])" "[$FROM_ADDRESS]" --private-key $CURRENT_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG
cast send $PACKET_CONSUMER_ADDRESS "revokeRole(bytes32, address)" $ADMIN_ROLE $FROM_ADDRESS --private-key $CURRENT_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG
