#!/bin/bash

set -e

# ================================================
# Environment variables; EDIT THIS
# ================================================

echo "========== Setting environment variables =========="

# Destination Chain
RPC_URL=
export TARGET_CHAIN_ID=
RELAYER_ADDR=
RELAYER_BALANCE=
export GAS_TYPE=eip1559
export PRIORITY_FEE=1wei
export GAS_PRICE=
export REFUNDABLE=true
export TRANSITION_PERIOD=172800
OPERATOR_ADDRESS=

# Bandchain
BANDCHAIN_RPC_URL=https://rpc.laozi3.bandchain.org/

echo "Getting SOURCE_CHAIN_ID from BandChain node $BANDCHAIN_RPC_URL ..."
export SOURCE_CHAIN_ID=$(bandd status --node $BANDCHAIN_RPC_URL --output json | jq -r '.node_info.network')
echo "Source chain ID: $SOURCE_CHAIN_ID"
echo "Getting TSS public key from BandChain ..."
TSS_PUBLIC_KEY_BASE64=$(bandd q bandtss current-group --node $BANDCHAIN_RPC_URL --output json | jq -r '.pub_key')
echo "Computing TRANSITION_ORIGINATOR_HASH ..."
export TRANSITION_ORIGINATOR_HASH=$({
  printf '%s' "DirectOriginator" | cast keccak | sed 's/^0x//' | xxd -r -p | head -c 4 
  printf '%s' "$SOURCE_CHAIN_ID" | cast keccak | sed 's/^0x//' | xxd -r -p
  printf '%s' "band1z4nmm3dvy47nfc4jyf6p8hnd3j3fz6lwjf0rfm" | cast keccak | sed 's/^0x//' | xxd -r -p
  printf '%s' ""            | cast keccak | sed 's/^0x//' | xxd -r -p
} | cast keccak)

# convert base64 to concatenated hex 
TSS_PUBLIC_KEY_HEX=$(echo $TSS_PUBLIC_KEY_BASE64 | base64 -d | xxd -p | tr -d '\n')
export TSS_PARITY=$(echo $TSS_PUBLIC_KEY_HEX | cut -c 2)
export TSS_PUBLIC_KEY=0x$(echo $TSS_PUBLIC_KEY_HEX | cut -c 3-)

# ================================================
# Summary
# ================================================

# trap: On any error or script exit, always print summary section
print_summary() {
    echo "================================================"
    echo "Summary"
    echo "Bandchain source chain ID: $SOURCE_CHAIN_ID (rpc url: $BANDCHAIN_RPC_URL)"
    echo "Target chain ID: $TARGET_CHAIN_ID (rpc url: $RPC_URL)"
    echo "Deployed contracts:"
    echo "Gas type: $GAS_TYPE "
    echo "Tunnel refundable: $REFUNDABLE"
    echo "VAULT(proxy): $VAULT"
    echo "VAULT(impl): $VAULT_IMPL"
    echo "VAULT(admin): $VAULT_ADMIN"
    echo "TSS_VERIFIER: $TSS_VERIFIER"
    echo "Tunnel router type: $TUNNEL_ROUTER_TYPE"
    echo "TUNNEL_ROUTER(proxy): $TUNNEL_ROUTER"
    echo "TUNNEL_ROUTER(impl): $TUNNEL_ROUTER_IMPL"
    echo "TUNNEL_ROUTER(admin): $TUNNEL_ROUTER_ADMIN"
    echo "================================================"
}
trap print_summary EXIT

# ================================================
# Deploy contracts
# ================================================

echo "========== Cleaning and Building contracts =========="
forge clean && forge build --optimize true --optimizer-runs 200

echo "========== Running deployment script to deploy contracts =========="
if [ "$GAS_TYPE" == "legacy" ]; then
    MSG=$(forge script script/SetupTunnelRouter.s.sol:Executor --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow --broadcast --optimize true --optimizer-runs 200 --legacy)
else
    MSG=$(forge script script/SetupTunnelRouter.s.sol:Executor --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow --broadcast --optimize true --optimizer-runs 200)
fi

echo "Parsing deployed contract addresses ..."
VAULT=$( echo "$MSG" | grep "Vault Proxy" | awk '{print $5}' | xargs)
VAULT_IMPL=$( echo "$MSG" | grep "Vault Implementation deployed at:" | awk '{print $5}' | xargs)
VAULT_ADMIN=$( echo "$MSG" | grep "Vault Admin deployed at:" | awk '{print $5}' | xargs)
TSS_VERIFIER=$( echo "$MSG" | grep "TssVerifier deployed at: " | awk '{print $4}' | xargs)
TUNNEL_ROUTER_TYPE=$( echo "$MSG" | grep "TunnelRouter type:" | awk '{print $3}' | xargs)
TUNNEL_ROUTER=$( echo "$MSG" | grep "TunnelRouter Proxy deployed at:" | awk '{print $5}' | xargs)
TUNNEL_ROUTER_IMPL=$( echo "$MSG" | grep "TunnelRouter Implementation deployed at:" | awk '{print $5}' | xargs)
TUNNEL_ROUTER_ADMIN=$( echo "$MSG" | grep "TunnelRouter Admin deployed at:" | awk '{print $5}' | xargs)
sleep 5

# ================================================
# Set up contracts
# ================================================

echo "========== Granting Relayer role in TunnelRouter =========="
if [ "$GAS_TYPE" == "legacy" ]; then
  cast send $TUNNEL_ROUTER "grantRelayer(address[])" "[$RELAYER_ADDR]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
else
  cast send $TUNNEL_ROUTER "grantRelayer(address[])" "[$RELAYER_ADDR]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
fi
sleep 5

echo "========== Granting GasFeeUpdater role to operator =========="
if [ "$GAS_TYPE" == "legacy" ]; then
  cast send $TUNNEL_ROUTER "grantGasFeeUpdater(address[])" "[$OPERATOR_ADDRESS]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
else 
  cast send $TUNNEL_ROUTER "grantGasFeeUpdater(address[])" "[$OPERATOR_ADDRESS]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
fi
sleep 5

echo "========== Sending initial balance to relayer(s) =========="
for addr in $(echo $RELAYER_ADDR | tr ',' ' '); do
    echo "Sending balance to relayer $addr"
    if [ "$GAS_TYPE" == "legacy" ]; then
      cast send $addr --value $RELAYER_BALANCE --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy
    else
      cast send $addr --value $RELAYER_BALANCE --private-key $PRIVATE_KEY --rpc-url $RPC_URL
    fi
    sleep 1
done
