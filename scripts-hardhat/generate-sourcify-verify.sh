#!/bin/bash

# Generate Sourcify packages from Hardhat's build-info
# This uses the actual metadata from Hardhat's deployment compilation

set -e

OUTPUT_DIR="./sourcify-hardhat"

echo "=================================================="
echo "Compiling contracts with Hardhat..."
echo "=================================================="
npx hardhat compile --force

echo ""
echo "Finding latest build-info file..."
BUILD_INFO=$(ls -t ./out/build-info/*.json | head -1)

if [ ! -f "$BUILD_INFO" ]; then
    echo "ERROR: No build-info file found!"
    exit 1
fi

echo "Using build-info: $BUILD_INFO"

# Create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo ""
echo "=================================================="
echo "Extracting Sourcify packages from Hardhat build-info..."
echo "=================================================="

# Process contracts one by one
process_contract() {
    local CONTRACT_PATH="$1"
    local CONTRACT_NAME="$2"
    echo ""
    echo "Processing $CONTRACT_NAME..."
    
    # Create contract directory
    local CONTRACT_DIR="$OUTPUT_DIR/$CONTRACT_NAME"
    mkdir -p "$CONTRACT_DIR"
    
    # Extract metadata from build-info
    local METADATA=$(jq -r ".output.contracts[\"$CONTRACT_PATH\"][\"$CONTRACT_NAME\"].metadata" "$BUILD_INFO")
    
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
        local SOURCE_CONTENT=$(jq -r ".input.sources[\"$SOURCE_FILE\"].content" "$BUILD_INFO")
        
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

# Process each contract
process_contract "src/router/PriorityFeeTunnelRouter.sol" "PriorityFeeTunnelRouter"
process_contract "src/router/GasPriceTunnelRouter.sol" "GasPriceTunnelRouter"
process_contract "src/TssVerifier.sol" "TssVerifier"
process_contract "src/Vault.sol" "Vault"
process_contract "src/PacketConsumer.sol" "PacketConsumer"
process_contract "src/PacketConsumerTick.sol" "PacketConsumerTick"
process_contract "src/PacketConsumerProxy.sol" "PacketConsumerProxy"

echo ""
echo "=================================================="
echo "Creating zip files for easy upload..."
echo "=================================================="

cd "$OUTPUT_DIR"
for CONTRACT_DIR in */; do
    CONTRACT_NAME="${CONTRACT_DIR%/}"
    echo "Creating ${CONTRACT_NAME}.zip..."
    zip -r "${CONTRACT_NAME}.zip" "$CONTRACT_NAME/" > /dev/null 2>&1
done
cd ..
