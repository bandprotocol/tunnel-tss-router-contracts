#!/bin/bash

# Generate standard JSON input for OpenZeppelin proxy contracts
# These are pre-compiled by @openzeppelin/hardhat-upgrades plugin

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=================================================="
echo "Generating Standard JSON for OpenZeppelin Proxies"
echo -e "==================================================${NC}"
echo ""

# Check if OpenZeppelin plugin artifacts exist
OZ_BUILD_INFO="node_modules/@openzeppelin/upgrades-core/artifacts/build-info-v5.json"

if [ ! -f "$OZ_BUILD_INFO" ]; then
    echo -e "${RED}Error: OpenZeppelin build-info not found${NC}"
    echo "Expected: $OZ_BUILD_INFO"
    echo ""
    echo "Make sure @openzeppelin/hardhat-upgrades is installed:"
    echo "npm install --save-dev @openzeppelin/hardhat-upgrades"
    exit 1
fi

echo -e "${BLUE}Step 1: Found OpenZeppelin build info${NC}"
echo "Location: $OZ_BUILD_INFO"
echo ""

# Extract standard JSON input for proxy contracts
echo -e "${BLUE}Step 2: Extracting standard JSON inputs...${NC}"
echo ""

# TransparentUpgradeableProxy
echo -e "${YELLOW}→ TransparentUpgradeableProxy${NC}"
jq '.input' "$OZ_BUILD_INFO" > TransparentUpgradeableProxy-standard-json.json
echo -e "  ${GREEN}✅ TransparentUpgradeableProxy-standard-json.json${NC}"

# ProxyAdmin
echo -e "${YELLOW}→ ProxyAdmin${NC}"
jq '.input' "$OZ_BUILD_INFO" > ProxyAdmin-standard-json.json
echo -e "  ${GREEN}✅ ProxyAdmin-standard-json.json${NC}"

echo ""
echo -e "${GREEN}=================================================="
echo "✅ OpenZeppelin proxy standard JSONs generated!"
echo -e "==================================================${NC}"
echo ""
