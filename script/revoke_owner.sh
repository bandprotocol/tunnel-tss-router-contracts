#!/bin/bash

set -e

RPC_URL=

TUNNEL_ROUTER_PROXY_ADDRESS=
PACKET_CONSUMER_ADDRESS=

FROM_ADDRESS=

GAS_TYPE=eip1559

# Note: Before running this script, export the following environment variables in your shell:
#       export PRIVATE_KEY=<your_private_key>

if [ "$GAS_TYPE" == "legacy" ]; then
    GAS_TYPE_FLAG=--legacy
else
    GAS_TYPE_FLAG=
fi

ADMIN_ROLE=$(cast to-bytes32 0x00)

# Revoke all roles of the TunnelRouter contract
cast send "$TUNNEL_ROUTER_PROXY_ADDRESS" "revokeGasFeeUpdater(address[])" "[$FROM_ADDRESS]" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
sleep 5
cast send "$TUNNEL_ROUTER_PROXY_ADDRESS" "revokeRole(bytes32,address)" $ADMIN_ROLE "$FROM_ADDRESS" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
sleep 5

# Revoke all roles of the PacketConsumer contract
cast send "$PACKET_CONSUMER_ADDRESS" "revokeTunnelActivatorRole(address[])" "[$FROM_ADDRESS]" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
sleep 5
cast send "$PACKET_CONSUMER_ADDRESS" "revokeRole(bytes32,address)" $ADMIN_ROLE "$FROM_ADDRESS" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
sleep 5

# Print Summary at end
echo "================================================"
echo "Summary of role revocations from: $FROM_ADDRESS"
echo ""
echo "- TunnelRouterProxy ($TUNNEL_ROUTER_PROXY_ADDRESS):"
echo "    ✓ Revoked GasFeeUpdater role"
echo "    ✓ Revoked ADMIN role"
echo ""
echo "- PacketConsumer ($PACKET_CONSUMER_ADDRESS):"
echo "    ✓ Revoked TunnelActivator role"
echo "    ✓ Revoked ADMIN role"
echo ""
echo "================================================"
echo "NEXT STEP: Run verify_owner.sh to confirm all permissions are correct"
echo "================================================"
