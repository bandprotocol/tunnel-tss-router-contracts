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

echo "========== Running deployment script to deploy Vault =========="
forge clean && forge build --optimize true --optimizer-runs 200
MSG=$(forge script script/VaultScript.s.sol:Executor --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow --broadcast --optimize true --optimizer-runs 200)
sleep 2
export VAULT_IMPL=$( echo "$MSG" | grep "Vault Implementation deployed at:" | awk '{print $5}' | xargs)

echo "========== Running deployment script to deploy Vault Proxy =========="
forge clean && forge build --optimize true --optimizer-runs 200
MSG=$(forge script script/VaultProxyScript.s.sol:Executor --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow --broadcast --optimize true --optimizer-runs 200)
sleep 2
export VAULT=$( echo "$MSG" | grep "Vault Proxy" | awk '{print $5}' | xargs)
VAULT_ADMIN=$( echo "$MSG" | grep "Vault Admin deployed at:" | awk '{print $5}' | xargs)

echo "========== Running deployment script to deploy Tss Verifier =========="
forge clean && forge build --optimize true --optimizer-runs 200
MSG=$(forge script script/TssVerifierScript.s.sol:Executor --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow --broadcast --optimize true --optimizer-runs 200)
sleep 2
export TSS_VERIFIER=$( echo "$MSG" | grep "TssVerifier deployed at: " | awk '{print $4}' | xargs)

echo "========== Running deployment script to deploy Tunnel Router =========="
forge clean && forge build --optimize true --optimizer-runs 200
MSG=$(forge script script/TunnelRouterScript.s.sol:Executor --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow --broadcast --optimize true --optimizer-runs 200)
sleep 2
export TUNNEL_ROUTER_IMPL=$( echo "$MSG" | grep "PriorityFeeTunnelRouter Implementation deployed at:" | awk '{print $5}' | xargs)

echo "========== Running deployment script to deploy Tunnel Router Proxy =========="
forge clean && forge build --optimize true --optimizer-runs 200
MSG=$(forge script script/TunnelRouterProxyScript.s.sol:Executor --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow --broadcast --optimize true --optimizer-runs 200)
sleep 2
TUNNEL_ROUTER=$( echo "$MSG" | grep "PriorityFeeTunnelRouter Proxy deployed at:" | awk '{print $5}' | xargs)
TUNNEL_ROUTER_ADMIN=$( echo "$MSG" | grep "PriorityFeeTunnelRouter Admin deployed at:" | awk '{print $5}' | xargs)

# ================================================
# Set up contracts
# ================================================

echo "========== Add Pub Key by Owner in TssVerifier =========="
cast send $TSS_VERIFIER "addPubKeyByOwner(uint64, uint8, uint256)" 0 $TSS_PARITY $TSS_PUBLIC_KEY --gas-limit 300000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
sleep 2

echo "========== Set Tunnel Router in Vault =========="
cast send $VAULT "setTunnelRouter(address)" $TUNNEL_ROUTER --gas-limit 300000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
sleep 2

echo "========== Granting Relayer role in TunnelRouter =========="
cast send $TUNNEL_ROUTER "grantRelayer(address[])" "[$RELAYER_ADDR]" --gas-limit 500000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
sleep 2

echo "========== Granting GasFeeUpdater role to operator =========="
cast send $TUNNEL_ROUTER "grantGasFeeUpdater(address[])" "[$OPERATOR_ADDRESS]" --gas-limit 300000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
sleep 2

echo "========== Sending initial balance to relayer(s) =========="
for addr in $(echo $RELAYER_ADDR | tr ',' ' '); do
    echo "Sending balance to relayer $addr"
    cast send $addr --value $RELAYER_BALANCE --gas-limit 300000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
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
