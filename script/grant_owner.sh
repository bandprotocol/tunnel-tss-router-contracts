RPC_URL=

TUNNEL_ROUTER_ADDRESS=
VAULT_ADDRESS=
TSS_VERIFIER_ADDRESS=
PACKET_CONSUMER_ADDRESS=
PACKET_CONSUMER_PROXY_ADRESS=

TO_ADDRESS=

ZKSYNC=false
GAS_TYPE=eip1559

# Note: Before running this script, export the following environment variables in your shell:
#       export CURRENT_OWNER_PRIVATE_KEY=<your_current_owner_private_key>
#       export NEW_OWNER_PRIVATE_KEY=<your_new_owner_private_key>

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

# Grants all roles of the TunnelRouter contract
cast send $TUNNEL_ROUTER_ADDRESS "grantGasFeeUpdater(address[])" "[$TO_ADDRESS]" --private-key $CURRENT_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG
cast send $TUNNEL_ROUTER_ADDRESS "grantRole(bytes32, address)" $ADMIN_ROLE $TO_ADDRESS --private-key $CURRENT_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG

# Transfers ownership of the Vault contract
cast send $VAULT_ADDRESS "transferOwnership(address)" $TO_ADDRESS --private-key $CURRENT_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG
cast send $VAULT_ADDRESS "acceptOwnership()" --private-key $NEW_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG

# Transfers ownership of the TssVerifier contract
cast send $TSS_VERIFIER_ADDRESS "transferOwnership(address)" $TO_ADDRESS --private-key $CURRENT_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG
cast send $TSS_VERIFIER_ADDRESS "acceptOwnership()" --private-key $NEW_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG

# Grants all rolesof the PacketConsumer contract
cast send $PACKET_CONSUMER_ADDRESS "grantTunnelActivatorRole(address[])" "[$TO_ADDRESS]" --private-key $CURRENT_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG
cast send $PACKET_CONSUMER_ADDRESS "grantRole(bytes32, address)" $ADMIN_ROLE $TO_ADDRESS --private-key $CURRENT_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG

# Transfers ownership of the TunnelRouter contract
cast send $PACKET_CONSUMER_PROXY_ADRESS "transferOwnership(address)" $TO_ADDRESS --private-key $CURRENT_OWNER_PRIVATE_KEY --rpc-url $RPC_URL $GAS_TYPE_FLAG $ZKSYNC_FLAG
