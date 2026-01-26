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
export PRIORITY_FEE=1wei
export TRANSITION_PERIOD=172800
export REFUNDABLE=true
OPERATOR_ADDRESS=

# Bandchain
BANDCHAIN_RPC_URL=https://rpc.laozi3.bandchain.org/

echo "Getting SOURCE_CHAIN_ID from BandChain node $BANDCHAIN_RPC_URL ..."
export SOURCE_CHAIN_ID=$(bandd status --node $BANDCHAIN_RPC_URL --output json | jq -r '.node_info.network')
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
# Deploy contracts
# ================================================

echo "========== Cleaning and Building contracts =========="
forge clean && forge build --optimize true --optimizer-runs 200

echo "========== Running deployment script to deploy contracts =========="
MSG=$(forge script script/SetupPriorityFeeTunnelRouter.s.sol:Executor --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow --broadcast  --optimize true --optimizer-runs 200)

echo "Parsing deployed contract addresses ..."
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

echo "========== Granting Relayer role in TunnelRouter =========="
cast send $TUNNEL_ROUTER "grantRelayer(address[])" "[$RELAYER_ADDR]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
sleep 2

echo "========== Granting GasFeeUpdater role to operator =========="
cast send $TUNNEL_ROUTER "grantGasFeeUpdater(address[])" "[$OPERATOR_ADDRESS]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
sleep 2

echo "========== Sending initial balance to relayer(s) =========="
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
