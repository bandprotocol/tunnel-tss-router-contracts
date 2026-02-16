#!/bin/bash

set -e

RPC_URL=

TUNNEL_ROUTER_PROXY_ADDRESS=
VAULT_PROXY_ADDRESS=
TSS_VERIFIER_ADDRESS=
PACKET_CONSUMER_ADDRESS=
PACKET_CONSUMER_PROXY_ADDRESS=

TO_ADDRESS=

GAS_TYPE=eip1559

# Note: Before running this script, export the following environment variables in your shell:
#       export PRIVATE_KEY=<your_private_key>

if [ "$GAS_TYPE" == "legacy" ]; then
    GAS_TYPE_FLAG=--legacy
else
    GAS_TYPE_FLAG=
fi

ADMIN_ROLE=$(cast to-bytes32 0x00)

# Function to get proxy admin
get_proxy_admin() {
    local proxy_address="$1"
    # Storage slot for EIP-1967 admin: keccak256("eip1967.proxy.admin") - 1
    local admin_slot="0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
    local admin_raw
    admin_raw=$(cast storage "$proxy_address" "$admin_slot" --rpc-url "$RPC_URL" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$admin_raw" ]; then
        # Remove leading zeros in the address
        admin="0x$(echo "${admin_raw:26}")"
        echo "$admin"
    else
        echo ""
    fi
}

# Function to get owner from Ownable contracts
get_owner() {
    local contract_address="$1"
    local owner
    owner=$(cast call "$contract_address" "owner()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$owner" ]; then
        echo "$owner"
    else
        echo ""
    fi
}

TUNNEL_ROUTER_PROXY_ADMIN=$(get_proxy_admin "$TUNNEL_ROUTER_PROXY_ADDRESS")
VAULT_PROXY_ADMIN=$(get_proxy_admin "$VAULT_PROXY_ADDRESS")

TUNNEL_ROUTER_PROXY_ADMIN_OWNER=$(get_owner "$TUNNEL_ROUTER_PROXY_ADMIN")
VAULT_PROXY_OWNER=$(get_owner "$VAULT_PROXY_ADDRESS")
VAULT_PROXY_ADMIN_OWNER=$(get_owner "$VAULT_PROXY_ADMIN")
TSS_VERIFIER_OWNER=$(get_owner "$TSS_VERIFIER_ADDRESS")
PACKET_CONSUMER_PROXY_OWNER=$(get_owner "$PACKET_CONSUMER_PROXY_ADDRESS")

# Grant all roles of the TunnelRouter contract
cast send "$TUNNEL_ROUTER_PROXY_ADDRESS" "grantGasFeeUpdater(address[])" "[$TO_ADDRESS]" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
sleep 5
cast send "$TUNNEL_ROUTER_PROXY_ADDRESS" "grantRole(bytes32, address)" $ADMIN_ROLE "$TO_ADDRESS" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
sleep 5
if [ -n "$TUNNEL_ROUTER_PROXY_ADMIN" ] && [ "$TUNNEL_ROUTER_PROXY_ADMIN_OWNER" != "$TO_ADDRESS" ]; then
    cast send "$TUNNEL_ROUTER_PROXY_ADMIN" "transferOwnership(address)" "$TO_ADDRESS" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
    sleep 5
fi

# Transfer ownership of the Vault contract (Ownable2Step - requires acceptOwnership)
if [ "$VAULT_PROXY_OWNER" != "$TO_ADDRESS" ]; then
    echo "Transferring Vault ownership to $TO_ADDRESS..."
    cast send "$VAULT_PROXY_ADDRESS" "transferOwnership(address)" "$TO_ADDRESS" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
    sleep 5
fi
if [ -n "$VAULT_PROXY_ADMIN" ] && [ "$VAULT_PROXY_ADMIN_OWNER" != "$TO_ADDRESS" ]; then
    echo "Transferring Vault Proxy Admin ownership to $TO_ADDRESS..."
    cast send "$VAULT_PROXY_ADMIN" "transferOwnership(address)" "$TO_ADDRESS" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
    sleep 5
fi

# Transfer ownership of the TssVerifier contract (Ownable2Step - requires acceptOwnership)
if [ "$TSS_VERIFIER_OWNER" != "$TO_ADDRESS" ]; then
    echo "Transferring TssVerifier ownership to $TO_ADDRESS..."
    cast send "$TSS_VERIFIER_ADDRESS" "transferOwnership(address)" "$TO_ADDRESS" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
    sleep 5
fi

# Grant all roles of the PacketConsumer contract
cast send "$PACKET_CONSUMER_ADDRESS" "grantTunnelActivatorRole(address[])" "[$TO_ADDRESS]" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
sleep 5
cast send "$PACKET_CONSUMER_ADDRESS" "grantRole(bytes32, address)" $ADMIN_ROLE "$TO_ADDRESS" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
sleep 5

# Transfer ownership of the PacketConsumerProxy contract
if [ "$PACKET_CONSUMER_PROXY_OWNER" != "$TO_ADDRESS" ]; then
    cast send "$PACKET_CONSUMER_PROXY_ADDRESS" "transferOwnership(address)" "$TO_ADDRESS" --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" $GAS_TYPE_FLAG
    sleep 5
fi

# Print Summary at end
echo "================================================"
echo "Summary of role/ownership transfers to: $TO_ADDRESS"
echo ""
echo "- TunnelRouterProxy ($TUNNEL_ROUTER_PROXY_ADDRESS):"
echo "    ✓ Granted GasFeeUpdater role"
echo "    ✓ Granted ADMIN role"
if [ -n "$TUNNEL_ROUTER_PROXY_ADMIN" ]; then
    echo "    Proxy admin address: $TUNNEL_ROUTER_PROXY_ADMIN"
    echo "    ✓ Transferred Proxy Admin ownership"
fi
echo ""
echo "- VaultProxy ($VAULT_PROXY_ADDRESS):"
echo "    ✓ Ownership transfer initiated (Ownable2Step)"
if [ -n "$VAULT_PROXY_ADMIN" ]; then
    echo "    Proxy admin address: $VAULT_PROXY_ADMIN"
    echo "    ✓ Vault Proxy Admin ownership transferred"
fi
echo ""
echo "- TssVerifier ($TSS_VERIFIER_ADDRESS):"
echo "    ✓ Ownership transfer initiated (Ownable2Step)"
echo ""
echo "- PacketConsumer ($PACKET_CONSUMER_ADDRESS):"
echo "    ✓ Granted TunnelActivator role"
echo "    ✓ Granted ADMIN role"
echo ""
echo "- PacketConsumerProxy ($PACKET_CONSUMER_PROXY_ADDRESS):"
echo "    ✓ Ownership transferred"
echo ""
echo "================================================"
echo "NEXT STEPS:"
echo "1. New owner ($TO_ADDRESS) must accept ownership:"
echo "   cast send $VAULT_PROXY_ADDRESS 'acceptOwnership()' --private-key <NEW_OWNER_KEY> --rpc-url $RPC_URL"
echo "   cast send $TSS_VERIFIER_ADDRESS 'acceptOwnership()' --private-key <NEW_OWNER_KEY> --rpc-url $RPC_URL"
echo ""
echo "2. After accepting ownership, run: ./revoke_owner.sh"
echo ""
echo "3. Verify everything with: ./verify_owner.sh"
echo "================================================"
