#!/bin/bash

# Generate Sourcify packages from OpenZeppelin hardhat-upgrades plugin artifacts
# These are the ACTUAL proxies deployed by the plugin

set -e

PLUGIN_BUILD_INFO="node_modules/@openzeppelin/upgrades-core/artifacts/build-info-v5.json"
OUTPUT_DIR="./sourcify-openzeppelin"

echo "=================================================="
echo "Generating Sourcify packages from OpenZeppelin plugin"
echo "=================================================="
echo ""

if [ ! -f "$PLUGIN_BUILD_INFO" ]; then
    echo "ERROR: Plugin build-info not found at $PLUGIN_BUILD_INFO"
    exit 1
fi

# Create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

process_contract() {
    local CONTRACT_PATH="$1"
    local CONTRACT_NAME="$2"
    
    echo "Processing $CONTRACT_NAME..."
    
    # Create contract directory
    local CONTRACT_DIR="$OUTPUT_DIR/$CONTRACT_NAME"
    mkdir -p "$CONTRACT_DIR"
    
    # Extract metadata from build-info
    local METADATA=$(jq -r ".output.contracts[\"$CONTRACT_PATH\"][\"$CONTRACT_NAME\"].metadata" "$PLUGIN_BUILD_INFO")
    
    if [ "$METADATA" = "null" ] || [ -z "$METADATA" ]; then
        echo "ERROR: No metadata found for $CONTRACT_NAME in $CONTRACT_PATH"
        return 1
    fi
    
    # Save metadata.json
    echo "$METADATA" > "$CONTRACT_DIR/metadata.json"
    
    # Extract sources from metadata
    echo "$METADATA" | jq -r '.sources | keys[]' | while read -r SOURCE_FILE; do
        echo "  - Extracting $SOURCE_FILE"
        
        # Get source content from build-info input
        local SOURCE_CONTENT=$(jq -r ".input.sources[\"$SOURCE_FILE\"].content" "$PLUGIN_BUILD_INFO")
        
        if [ "$SOURCE_CONTENT" = "null" ] || [ -z "$SOURCE_CONTENT" ]; then
            echo "    WARNING: No source content found for $SOURCE_FILE"
            continue
        fi
        
        # Create directory structure
        local SOURCE_DIR="$CONTRACT_DIR/$(dirname "$SOURCE_FILE")"
        mkdir -p "$SOURCE_DIR"
        
        # Save source file
        echo "$SOURCE_CONTENT" > "$CONTRACT_DIR/$SOURCE_FILE"
    done
    
    echo "✓ Created Sourcify package at $CONTRACT_DIR/"
}

# Process OpenZeppelin proxy contracts
process_contract "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol" "TransparentUpgradeableProxy"
process_contract "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol" "ProxyAdmin"

echo ""
echo "=================================================="
echo "Creating zip files..."
echo "=================================================="

cd "$OUTPUT_DIR"
for CONTRACT_DIR in */; do
    CONTRACT_NAME="${CONTRACT_DIR%/}"
    echo "Creating ${CONTRACT_NAME}.zip..."
    zip -r "${CONTRACT_NAME}.zip" "$CONTRACT_NAME/" > /dev/null 2>&1
done
cd ..
