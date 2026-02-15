#!/bin/bash

# Generate Standard JSON Input files for zkSync contract verification
# Uses zkSync build-info files from Hardhat compilation

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================================="
echo "Generating Standard JSON Input for zkSync Contracts"
echo -e "=========================================================${NC}"
echo ""

# Create temporary helper contract to include OpenZeppelin proxies
TEMP_CONTRACT="src/ProxyHelper.sol"
cat > "$TEMP_CONTRACT" << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
contract ProxyHelper {}
EOF

# Compile with zkSync to generate artifacts and build-info
export USE_ZKSYNC=true
export ETH_NETWORK=sepolia
export RPC_URL="${RPC_URL:-http://localhost:8545}"

echo -e "${BLUE}Compiling contracts with zkSync...${NC}"
npx hardhat compile --force --network localhost
echo ""

# Clean up temporary file
rm -f "$TEMP_CONTRACT"

# Find build-info files from zkSync compilation
BUILD_INFO_DIR="out-zk/build-info"

if [ ! -d "$BUILD_INFO_DIR" ] || [ -z "$(ls -A $BUILD_INFO_DIR 2>/dev/null)" ]; then
    echo -e "${RED}Error: No build-info found in ${BUILD_INFO_DIR}${NC}"
    exit 1
fi

# Find the largest build-info files (they contain different contract sets)
BUILD_INFO_FILES=($(ls -S "$BUILD_INFO_DIR"/*.json 2>/dev/null))

if [ ${#BUILD_INFO_FILES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No build-info files found${NC}"
    exit 1
fi

# Use the most comprehensive build-info file
MAIN_BUILD_INFO="${BUILD_INFO_FILES[0]}"

# Check if there's a second build-info (likely has ProxyHelper contracts)
if [ ${#BUILD_INFO_FILES[@]} -gt 1 ]; then
    PROXY_BUILD_INFO="${BUILD_INFO_FILES[1]}"
else
    PROXY_BUILD_INFO="$MAIN_BUILD_INFO"
fi

echo -e "${GREEN}Using main build-info: ${MAIN_BUILD_INFO}${NC}"
if [ "$PROXY_BUILD_INFO" != "$MAIN_BUILD_INFO" ]; then
    echo -e "${GREEN}Using proxy build-info: ${PROXY_BUILD_INFO}${NC}"
fi
echo ""

# Create output directory
OUTPUT_DIR="zksync-verify"
mkdir -p "$OUTPUT_DIR"

# Extract Standard JSON Input for all contracts
echo -e "${BLUE}Extracting Standard JSON inputs...${NC}"
echo ""

# Function to generate Standard JSON for a contract
generate_standard_json() {
    local contract_name=$1
    local build_info_file=$2
    local output_file="${OUTPUT_DIR}/${contract_name}-standard-json.json"
    
    echo -e "${YELLOW}→ ${contract_name}${NC}"
    
    # Extract the standard JSON input (sources + settings)
    jq '.input' "$build_info_file" > "$output_file"
    
    echo -e "  ${GREEN}✅ ${output_file}${NC}"
}

# Generate for main contracts (from main build-info)
generate_standard_json "PriorityFeeTunnelRouter" "$MAIN_BUILD_INFO"
generate_standard_json "GasPriceTunnelRouter" "$MAIN_BUILD_INFO"
generate_standard_json "TssVerifier" "$MAIN_BUILD_INFO"
generate_standard_json "Vault" "$MAIN_BUILD_INFO"
generate_standard_json "PacketConsumer" "$MAIN_BUILD_INFO"
generate_standard_json "PacketConsumerTick" "$MAIN_BUILD_INFO"
generate_standard_json "PacketConsumerProxy" "$MAIN_BUILD_INFO"

echo ""
echo -e "${BLUE}Generating Standard JSON for OpenZeppelin proxies...${NC}"
echo ""

# OpenZeppelin proxy contracts (from proxy build-info)
generate_standard_json "ProxyAdmin" "$PROXY_BUILD_INFO"
generate_standard_json "TransparentUpgradeableProxy" "$PROXY_BUILD_INFO"

echo ""
echo -e "${GREEN}========================================================="
echo "✅ All Standard JSON files generated in ${OUTPUT_DIR}/"
echo -e "=========================================================${NC}"
echo ""
echo "Files contain complete source code in Standard JSON Input format."
echo ""
echo "For zkSync block explorer verification:"
echo "1. Go to your deployed contract address"
echo "2. Click 'Verify & Publish'"
echo "3. Select 'Solidity (Standard JSON Input)'"
echo "4. Upload the *-standard-json.json file for your contract"
echo "5. Compiler: zksolc (check version in hardhat.config.js)"
echo "6. Make sure constructor arguments match deployment"
echo ""
