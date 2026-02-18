#!/bin/bash

# Generate ALL standard JSON inputs at once
# Combines both user contracts and OpenZeppelin proxy contracts

set -e

echo "=================================================="
echo "Generating ALL Standard JSON Inputs"
echo "=================================================="
echo ""

echo "Step 1: Generating user contract standard JSONs..."
./scripts-hardhat/generate-all-standard-json.sh

echo ""
echo "Step 2: Generating OpenZeppelin proxy standard JSONs..."
./scripts-hardhat/generate-proxy-standard-json.sh
