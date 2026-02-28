#!/bin/bash

# Generate standard JSON input for all contracts
# Equivalent to: forge verify-contract --show-standard-json-input for each contract

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=================================================="
echo "Generating Standard JSON Input for All Contracts"
echo -e "==================================================${NC}"
echo ""

# Compile once
echo -e "${BLUE}Step 1: Compiling all contracts...${NC}"
npx hardhat compile --force
echo ""

# Find the latest build-info file
BUILD_INFO_DIR="out/build-info"
if [ ! -d "$BUILD_INFO_DIR" ]; then
    BUILD_INFO_DIR="artifacts/build-info"
fi

LATEST_BUILD_INFO=$(ls -t "$BUILD_INFO_DIR"/*.json 2>/dev/null | head -1)

if [ -z "$LATEST_BUILD_INFO" ]; then
    echo -e "${RED}Error: No build-info files found${NC}"
    exit 1
fi

echo -e "${BLUE}Step 2: Using build info: ${LATEST_BUILD_INFO}${NC}"
echo ""

# List of contracts to generate standard JSON for
declare -a CONTRACTS=(
    "PriorityFeeTunnelRouter"
    "GasPriceTunnelRouter"
    "TssVerifier"
    "Vault"
    "PacketConsumer"
    "PacketConsumerTick"
    "PacketConsumerProxy"
)

echo -e "${BLUE}Step 3: Extracting standard JSON inputs...${NC}"
echo ""

# Extract for each contract
for CONTRACT in "${CONTRACTS[@]}"; do
    OUTPUT_FILE="${CONTRACT}-standard-json.json"
    
    echo -e "${YELLOW}→ ${CONTRACT}${NC}"
    
    # Extract the standard JSON input (same for all contracts, it's the full compilation)
    jq '.input' "$LATEST_BUILD_INFO" > "$OUTPUT_FILE"
    
    echo -e "  ${GREEN}✅ ${OUTPUT_FILE}${NC}"
done

echo ""
echo -e "${GREEN}=================================================="
echo "✅ All standard JSON inputs generated!"
echo -e "==================================================${NC}"
echo ""
