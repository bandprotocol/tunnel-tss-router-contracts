# !/bin/bash

set -e

# ================================================
# Environment variables; EDIT THIS
# ================================================

RPC_URL=
BANDCHAIN_RPC_URL=
RELAYER_ADDR=
SOURCE_CHAIN_ID=
TARGET_CHAIN_ID=
PRIORITY_FEE=
TRANSITION_PERIOD=
RELAYER_BALANCE=

TSS_PUBLIC_KEY_BASE64=$(bandd q bandtss current-group --node $BANDCHAIN_RPC_URL --output json | jq -r '.pub_key')
TRANSITION_ORIGINATOR_HASH=$({
  printf '%s' "DirectOriginator" | cast keccak | sed 's/^0x//' | xxd -r -p | head -c 4 
  printf '%s' "$SOURCE_CHAIN_ID" | cast keccak | sed 's/^0x//' | xxd -r -p
  printf '%s' "band1z4nmm3dvy47nfc4jyf6p8hnd3j3fz6lwjf0rfm" | cast keccak | sed 's/^0x//' | xxd -r -p
  printf '%s' ""            | cast keccak | sed 's/^0x//' | xxd -r -p
} | cast keccak)

echo $TRANSITION_ORIGINATOR_HASH

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
VAULT_ADMIN=$( echo "$MSG" | grep "Vault Admin deployed at:" | awk '{print $5}' | xargs)
TSS_VERIFIER=$( echo "$MSG" | grep "TssVerifier deployed at: " | awk '{print $4}' | xargs)
TUNNEL_ROUTER=$( echo "$MSG" | grep "PriorityFeeTunnelRouter Proxy deployed at:" | awk '{print $5}' | xargs)
TUNNEL_ROUTER_IMPL=$( echo "$MSG" | grep "PriorityFeeTunnelRouter Implementation deployed at:" | awk '{print $5}' | xargs)
TUNNEL_ROUTER_ADMIN=$( echo "$MSG" | grep "PriorityFeeTunnelRouter Admin deployed at:" | awk '{print $5}' | xargs)

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
echo "VAULT(admin): $VAULT_ADMIN"
echo "TSS_VERIFIER: $TSS_VERIFIER"
echo "TUNNEL_ROUTER(proxy): $TUNNEL_ROUTER"
echo "TUNNEL_ROUTER(impl): $TUNNEL_ROUTER_IMPL"
echo "TUNNEL_ROUTER(admin): $TUNNEL_ROUTER_ADMIN"
echo "================================================"
