# !/bin/bash

set -e

# ================================================
# Environment variables; EDIT THIS
# ================================================

TSS_PUBLIC_KEY_BASE64=
RPC_URL=
PRIVATE_KEY=
RELAYER_ADDR=
SOURCE_CHAIN_ID=
TARGET_CHAIN_ID=
TRANSITION_ORIGINATOR_HASH=
PRIORITY_FEE=
TRANSITION_PERIOD=
RELAYER_BALANCE=

# ================================================
# Deploy contracts
# ================================================

forge clean & forge build --optimize true --optimizer-runs 200

export PRIVATE_KEY=$PRIVATE_KEY
export TRANSITION_PERIOD=$TRANSITION_PERIOD
export TARGET_CHAIN_ID=$TARGET_CHAIN_ID
export SOURCE_CHAIN_ID=$SOURCE_CHAIN_ID
export TRANSITION_ORIGINATOR_HASH=$TRANSITION_ORIGINATOR_HASH
export PRIORITY_FEE=$PRIORITY_FEE

MSG=$(forge script script/SetupPriorityFeeTunnelRouter.s.sol:Executor --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow --broadcast  --optimize true --optimizer-runs 200)
VAULT=$( echo "$MSG" | grep "Vault Proxy" | awk '{print $5}' | xargs)
VAULT_IMPL=$( echo "$MSG" | grep "Vault Implementation deployed at:" | awk '{print $5}' | xargs)
TSS_VERIFIER=$( echo "$MSG" | grep "TssVerifier deployed at: " | awk '{print $4}' | xargs)
TUNNEL_ROUTER=$( echo "$MSG" | grep "PriorityFeeTunnelRouter Proxy deployed at:" | awk '{print $5}' | xargs)
TUNNEL_ROUTER_IMPL=$( echo "$MSG" | grep "PriorityFeeTunnelRouter Implementation deployed at:" | awk '{print $5}' | xargs)

# ================================================
# Set up contracts
# ================================================

# convert base64 to concatenated hex 
TSS_PUBLIC_KEY_HEX=$(echo $TSS_PUBLIC_KEY_BASE64 | base64 -d | xxd -p | tr -d '\n')
TSS_PARITY=$(echo $TSS_PUBLIC_KEY_HEX | cut -c 2)
TSS_PUBLIC_KEY=0x$(echo $TSS_PUBLIC_KEY_HEX | cut -c 3-)
TIMESTAMP=0

# set up deployed contracts
cast send $TSS_VERIFIER "addPubKeyByOwner(uint64, uint8, uint256)" $TIMESTAMP $TSS_PARITY $TSS_PUBLIC_KEY --private-key $PRIVATE_KEY --rpc-url $RPC_URL
sleep 2
cast send $VAULT "setTunnelRouter(address)" $TUNNEL_ROUTER --private-key $PRIVATE_KEY --rpc-url $RPC_URL
sleep 2
cast send $TUNNEL_ROUTER "setWhitelist(address[], bool)" "[$RELAYER_ADDR]" true --private-key $PRIVATE_KEY --rpc-url $RPC_URL
sleep 2

for addr in $(echo $RELAYER_ADDR | tr ',' ' '); do
    echo "Sending balance to relayer $addr"
    cast send $addr --value $RELAYER_BALANCE --private-key $PRIVATE_KEY --rpc-url $RPC_URL
    sleep 1
done

echo "================================================"
echo "Deployed contracts:"
echo "VAULT(proxy): $VAULT"
echo "VAULT(impl): $VAULT_IMPL"
echo "TSS_VERIFIER: $TSS_VERIFIER"
echo "TUNNEL_ROUTER(proxy): $TUNNEL_ROUTER"
echo "TUNNEL_ROUTER(impl): $TUNNEL_ROUTER_IMPL"
echo "================================================"