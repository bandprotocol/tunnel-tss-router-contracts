#!/bin/bash

# RPC URL - Update with your RPC endpoint
RPC_URL=

# Contract Addresses - Update these with your deployed contract addresses
TUNNEL_ROUTER_PROXY=
VAULT_PROXY=
TSS_VERIFIER=
PACKET_CONSUMER=
PACKET_CONSUMER_PROXY=

# Addresses to check - Update these with your deployer and new owner addresses
OLD_DEPLOYER=
NEW_OWNER=

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Permission Transfer Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "OLD DEPLOYER: ${YELLOW}$OLD_DEPLOYER${NC}"
echo -e "NEW OWNER:    ${YELLOW}$NEW_OWNER${NC}"
echo ""

# Normalize addresses to lowercase for comparison
normalize_address() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

OLD_DEPLOYER_NORM=$(normalize_address "$OLD_DEPLOYER")
NEW_OWNER_NORM=$(normalize_address "$NEW_OWNER")

# Function to check if address matches
check_address() {
    local addr1=$(normalize_address "$1")
    local addr2=$(normalize_address "$2")
    [[ "$addr1" == "$addr2" ]]
}

# Function to display status
display_status() {
    local has_permission=$1
    local should_have=$2
    
    if [ "$has_permission" == "true" ]; then
        if [ "$should_have" == "true" ]; then
            echo -e "${GREEN}✓ HAS ACCESS${NC}"
        else
            echo -e "${RED}✗ STILL HAS ACCESS (Should be removed!)${NC}"
        fi
    else
        if [ "$should_have" == "true" ]; then
            echo -e "${RED}✗ NO ACCESS (Should have access!)${NC}"
        else
            echo -e "${GREEN}✓ No access${NC}"
        fi
    fi
}

# Function to get proxy admin
get_proxy_admin() {
    local proxy_address=$1
    # Storage slot for EIP-1967 admin: keccak256("eip1967.proxy.admin") - 1
    local admin_slot="0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
    local admin=$(cast storage "$proxy_address" "$admin_slot" --rpc-url "$RPC_URL" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$admin" ]; then
        # Convert to address format (remove leading zeros)
        admin="0x$(echo $admin | sed 's/0x000000000000000000000000//')"
        echo "$admin"
    else
        echo ""
    fi
}

# Function to get owner from Ownable contracts
get_owner() {
    local contract_address=$1
    local owner=$(cast call "$contract_address" "owner()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$owner" ]; then
        echo "$owner"
    else
        echo ""
    fi
}

# Function to get pending owner from Ownable2Step contracts
get_pending_owner() {
    local contract_address=$1
    local pending_owner=$(cast call "$contract_address" "pendingOwner()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$pending_owner" ] && [ "$pending_owner" != "0x0000000000000000000000000000000000000000" ]; then
        echo "$pending_owner"
    else
        echo ""
    fi
}

# Function to check if address has role
has_role() {
    local contract_address=$1
    local role=$2
    local account=$3
    
    local result=$(cast call "$contract_address" "hasRole(bytes32,address)(bool)" "$role" "$account" --rpc-url "$RPC_URL" 2>/dev/null)
    
    if [ "$result" == "true" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to get role member count
get_role_member_count() {
    local contract_address=$1
    local role=$2
    
    local count=$(cast call "$contract_address" "getRoleMemberCount(bytes32)(uint256)" "$role" --rpc-url "$RPC_URL" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$count" ]; then
        echo "$count"
    else
        echo "0"
    fi
}


echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}1. TunnelRouter (Proxy)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Address: ${GREEN}$TUNNEL_ROUTER_PROXY${NC}"

if [ "$TUNNEL_ROUTER_PROXY" != "0x0000000000000000000000000000000000000000" ]; then
    # Check Proxy Admin Owner
    proxy_admin=$(get_proxy_admin "$TUNNEL_ROUTER_PROXY")
    if [ ! -z "$proxy_admin" ]; then
        proxy_admin_owner=$(get_owner "$proxy_admin")
        echo -e "\n  ${BLUE}Proxy Admin:${NC} $proxy_admin"
        echo -e "  ${BLUE}Proxy Admin Owner:${NC} $proxy_admin_owner"
        
        echo -n "    OLD DEPLOYER: "
        if check_address "$proxy_admin_owner" "$OLD_DEPLOYER"; then
            display_status "true" "false"
        else
            display_status "false" "false"
        fi
        
        echo -n "    NEW OWNER:    "
        if check_address "$proxy_admin_owner" "$NEW_OWNER"; then
            display_status "true" "true"
        else
            display_status "false" "true"
        fi
    fi
    
    # Check DEFAULT_ADMIN_ROLE
    echo -e "\n  ${BLUE}DEFAULT_ADMIN_ROLE:${NC}"
    DEFAULT_ADMIN_ROLE="0x0000000000000000000000000000000000000000000000000000000000000000"
    
    echo -n "    OLD DEPLOYER: "
    old_has_admin=$(has_role "$TUNNEL_ROUTER_PROXY" "$DEFAULT_ADMIN_ROLE" "$OLD_DEPLOYER")
    display_status "$old_has_admin" "false"
    
    echo -n "    NEW OWNER:    "
    new_has_admin=$(has_role "$TUNNEL_ROUTER_PROXY" "$DEFAULT_ADMIN_ROLE" "$NEW_OWNER")
    display_status "$new_has_admin" "true"
    
    # Check GAS_FEE_UPDATER_ROLE
    echo -e "\n  ${BLUE}GAS_FEE_UPDATER_ROLE:${NC}"
    GAS_FEE_UPDATER_ROLE="0x$(cast keccak "GAS_FEE_UPDATER_ROLE" | tail -c 65)"
    
    echo -n "    OLD DEPLOYER: "
    old_has_gas=$(has_role "$TUNNEL_ROUTER_PROXY" "$GAS_FEE_UPDATER_ROLE" "$OLD_DEPLOYER")
    display_status "$old_has_gas" "false"
    
    echo -n "    NEW OWNER:    "
    new_has_gas=$(has_role "$TUNNEL_ROUTER_PROXY" "$GAS_FEE_UPDATER_ROLE" "$NEW_OWNER")
    display_status "$new_has_gas" "true"
else
    echo -e "   ${YELLOW}⚠ Address not set${NC}"
fi
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}2. Vault (Proxy)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Address: ${GREEN}$VAULT_PROXY${NC}"

if [ "$VAULT_PROXY" != "0x0000000000000000000000000000000000000000" ]; then
    # Check Proxy Admin Owner
    proxy_admin=$(get_proxy_admin "$VAULT_PROXY")
    if [ ! -z "$proxy_admin" ]; then
        proxy_admin_owner=$(get_owner "$proxy_admin")
        echo -e "\n  ${BLUE}Proxy Admin:${NC} $proxy_admin"
        echo -e "  ${BLUE}Proxy Admin Owner:${NC} $proxy_admin_owner"
        
        echo -n "    OLD DEPLOYER: "
        if check_address "$proxy_admin_owner" "$OLD_DEPLOYER"; then
            display_status "true" "false"
        else
            display_status "false" "false"
        fi
        
        echo -n "    NEW OWNER:    "
        if check_address "$proxy_admin_owner" "$NEW_OWNER"; then
            display_status "true" "true"
        else
            display_status "false" "true"
        fi
    fi
    
    # Check Owner (Ownable2Step)
    owner=$(get_owner "$VAULT_PROXY")
    echo -e "\n  ${BLUE}Owner (Ownable2Step):${NC} $owner"
    
    echo -n "    OLD DEPLOYER: "
    if check_address "$owner" "$OLD_DEPLOYER"; then
        display_status "true" "false"
    else
        display_status "false" "false"
    fi
    
    echo -n "    NEW OWNER:    "
    if check_address "$owner" "$NEW_OWNER"; then
        display_status "true" "true"
    else
        display_status "false" "true"
    fi
    
    # Check pending owner
    pending_owner=$(get_pending_owner "$VAULT_PROXY")
    if [ ! -z "$pending_owner" ]; then
        echo -e "\n  ${YELLOW}⚠ PENDING OWNERSHIP TRANSFER DETECTED!${NC}"
        echo -e "  ${BLUE}Pending Owner:${NC} $pending_owner"
        echo -e "  ${RED}Action Required: Pending owner must call acceptOwnership()${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠ Address not set${NC}"
fi
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}3. TSSVerifier${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Address: ${GREEN}$TSS_VERIFIER${NC}"

if [ "$TSS_VERIFIER" != "0x0000000000000000000000000000000000000000" ]; then
    owner=$(get_owner "$TSS_VERIFIER")
    echo -e "\n  ${BLUE}Owner (Ownable2Step):${NC} $owner"
    
    echo -n "    OLD DEPLOYER: "
    if check_address "$owner" "$OLD_DEPLOYER"; then
        display_status "true" "false"
    else
        display_status "false" "false"
    fi
    
    echo -n "    NEW OWNER:    "
    if check_address "$owner" "$NEW_OWNER"; then
        display_status "true" "true"
    else
        display_status "false" "true"
    fi
    
    # Check pending owner
    pending_owner=$(get_pending_owner "$TSS_VERIFIER")
    if [ ! -z "$pending_owner" ]; then
        echo -e "\n  ${YELLOW}⚠ PENDING OWNERSHIP TRANSFER DETECTED!${NC}"
        echo -e "  ${BLUE}Pending Owner:${NC} $pending_owner"
        echo -e "  ${RED}Action Required: Pending owner must call acceptOwnership()${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠ Address not set${NC}"
fi
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}4. PacketConsumer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Address: ${GREEN}$PACKET_CONSUMER${NC}"

if [ "$PACKET_CONSUMER" != "0x0000000000000000000000000000000000000000" ]; then
    # Check DEFAULT_ADMIN_ROLE
    echo -e "\n  ${BLUE}DEFAULT_ADMIN_ROLE:${NC}"
    DEFAULT_ADMIN_ROLE="0x0000000000000000000000000000000000000000000000000000000000000000"
    
    echo -n "    OLD DEPLOYER: "
    old_has_admin=$(has_role "$PACKET_CONSUMER" "$DEFAULT_ADMIN_ROLE" "$OLD_DEPLOYER")
    display_status "$old_has_admin" "false"
    
    echo -n "    NEW OWNER:    "
    new_has_admin=$(has_role "$PACKET_CONSUMER" "$DEFAULT_ADMIN_ROLE" "$NEW_OWNER")
    display_status "$new_has_admin" "true"
    
    # Check TUNNEL_ACTIVATOR_ROLE
    echo -e "\n  ${BLUE}TUNNEL_ACTIVATOR_ROLE:${NC}"
    TUNNEL_ACTIVATOR_ROLE="0x$(cast keccak "TUNNEL_ACTIVATOR_ROLE" | tail -c 65)"
    
    echo -n "    OLD DEPLOYER: "
    old_has_activator=$(has_role "$PACKET_CONSUMER" "$TUNNEL_ACTIVATOR_ROLE" "$OLD_DEPLOYER")
    display_status "$old_has_activator" "false"
    
    echo -n "    NEW OWNER:    "
    new_has_activator=$(has_role "$PACKET_CONSUMER" "$TUNNEL_ACTIVATOR_ROLE" "$NEW_OWNER")
    display_status "$new_has_activator" "true"
else
    echo -e "   ${YELLOW}⚠ Address not set${NC}"
fi
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}5. PacketConsumerProxy${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Address: ${GREEN}$PACKET_CONSUMER_PROXY${NC}"

if [ "$PACKET_CONSUMER_PROXY" != "0x0000000000000000000000000000000000000000" ]; then
    owner=$(get_owner "$PACKET_CONSUMER_PROXY")
    echo -e "\n  ${BLUE}Owner (Ownable):${NC} $owner"
    
    echo -n "    OLD DEPLOYER: "
    if check_address "$owner" "$OLD_DEPLOYER"; then
        display_status "true" "false"
    else
        display_status "false" "false"
    fi
    
    echo -n "    NEW OWNER:    "
    if check_address "$owner" "$NEW_OWNER"; then
        display_status "true" "true"
    else
        display_status "false" "true"
    fi
else
    echo -e "   ${YELLOW}⚠ Address not set${NC}"
fi
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Verification Complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"