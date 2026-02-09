#!/bin/bash

set -e

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# ================================================
# Environment variables; EDIT THIS
# ================================================

echo "========== Setting environment variables =========="

# Destination Chain
export RPC_URL=
export TARGET_CHAIN_ID=-testnet
export RELAYER_ADDR=
export RELAYER_BALANCE=0.1ether
export GAS_TYPE=eip1559
export PRIORITY_FEE=1wei
export GAS_PRICE=1gwei
export REFUNDABLE=true
export TRANSITION_PERIOD=172800
export OPERATOR_ADDRESS=

# Bandchain
export BANDCHAIN_RPC_URL=https://rpc.laozi3.bandchain.org/

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

# Set gas flags for cast commands
if [ "$GAS_TYPE" == "legacy" ]; then
    GAS_FLAG="--legacy"
else
    GAS_FLAG=""
fi

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

echo "========== Compiling contracts with Hardhat =========="
npx hardhat compile

echo "========== Running deployment script to deploy contracts =========="
DEPLOY_OUTPUT=$(npx hardhat run scripts-hardhat/deployTunnelRouter.js --network localhost)
echo "$DEPLOY_OUTPUT"

echo "Parsing deployed contract addresses ..."
VAULT=$(echo "$DEPLOY_OUTPUT" | grep "Vault Proxy:" | awk '{print $3}')
VAULT_IMPL=$(echo "$DEPLOY_OUTPUT" | grep "Vault Implementation:" | awk '{print $3}')
VAULT_ADMIN=$(echo "$DEPLOY_OUTPUT" | grep "Vault Admin:" | awk '{print $3}')
TSS_VERIFIER=$(echo "$DEPLOY_OUTPUT" | grep "TssVerifier:" | awk '{print $2}')
TUNNEL_ROUTER_TYPE=$(echo "$DEPLOY_OUTPUT" | grep "TunnelRouter type:" | awk '{print $3}')
TUNNEL_ROUTER=$(echo "$DEPLOY_OUTPUT" | grep "TunnelRouter Proxy:" | awk '{print $3}')
TUNNEL_ROUTER_IMPL=$(echo "$DEPLOY_OUTPUT" | grep "TunnelRouter Implementation:" | awk '{print $3}')
TUNNEL_ROUTER_ADMIN=$(echo "$DEPLOY_OUTPUT" | grep "TunnelRouter Admin:" | awk '{print $3}')

sleep 5

# ================================================
# Set up contracts
# ================================================

echo "========== Granting Relayer role in TunnelRouter =========="
# Note: Some RPCs return non-standard responses that cast can't parse, but the tx still succeeds
cast send $TUNNEL_ROUTER "grantRelayer(address[])" "[$RELAYER_ADDR]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL $GAS_FLAG 2>&1 | grep -E "(blockHash|transactionHash|Error: \()" || true
sleep 5

if [ -n "$OPERATOR_ADDRESS" ]; then
    echo "========== Granting GasFeeUpdater role to operator =========="
    cast send $TUNNEL_ROUTER "grantGasFeeUpdater(address[])" "[$OPERATOR_ADDRESS]" --private-key $PRIVATE_KEY --rpc-url $RPC_URL $GAS_FLAG 2>&1 | grep -E "(blockHash|transactionHash|Error: \()" || true
    sleep 5
else
    echo "========== Skipping GasFeeUpdater role grant (OPERATOR_ADDRESS not set) =========="
fi

echo "========== Sending initial balance to relayer(s) =========="
for addr in $(echo $RELAYER_ADDR | tr ',' ' '); do
    echo "Sending balance to relayer $addr"
    cast send $addr --value $RELAYER_BALANCE --private-key $PRIVATE_KEY --rpc-url $RPC_URL $GAS_FLAG 2>&1 | grep -E "(blockHash|transactionHash|Error: \()" || true
    sleep 1
done
