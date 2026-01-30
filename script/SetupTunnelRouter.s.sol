// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/Console.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {IVault} from "../src/interfaces/IVault.sol";
import {ITssVerifier} from "../src/interfaces/ITssVerifier.sol";

import {PriorityFeeTunnelRouter} from "../src/router/PriorityFeeTunnelRouter.sol";
import {GasPriceTunnelRouter} from "../src/router/GasPriceTunnelRouter.sol";
import {TssVerifier} from "../src/TssVerifier.sol";
import {Vault} from "../src/Vault.sol";

contract Executor is Script {
    function run() external {

        TssVerifier tssVerifier = deployTssVerifier();

        (address proxyVaultAddr, address implVaultAddr, address adminVaultAddr) = deployVault();

        string memory gasType = vm.envOR("GAS_TYPE", "eip1559");
        address proxyTunnelRouterAddr;
        address implTunnelRouterAddr;
        address adminTunnelRouterAddr;
        if(gasType == "eip1559") {
            (proxyTunnelRouterAddr, implTunnelRouterAddr, adminTunnelRouterAddr) = deployPriorityFeeTunnelRouter(tssVerifier, proxyVaultAddr);
        } else {
            (proxyTunnelRouterAddr, implTunnelRouterAddr, adminTunnelRouterAddr) = deployGasPriceTunnelRouter(tssVerifier, proxyVaultAddr);
        }

        vm.startBroadcast();
        // Set the tunnel router address in the vault
        Vault(payable(proxyVaultAddr)).setTunnelRouter(proxyTunnelRouterAddr);
        vm.stopBroadcast();

        console.log("Vault Proxy deployed at:", proxyVaultAddr);
        console.log("Vault Implementation deployed at:", implVaultAddr);
        console.log("Vault Admin deployed at:", adminVaultAddr);
        console.log("TssVerifier deployed at:", address(tssVerifier));
        console.log(
            "TunnelRouter Proxy deployed at:",
            proxyTunnelRouterAddr
        );
        console.log(
            "TunnelRouter Implementation deployed at:",
            implTunnelRouterAddr
        );
        console.log(
            "TunnelRouter Admin deployed at:",
            adminTunnelRouterAddr
        );
    }

    function deployVault() internal returns (address, address, address) {
        vm.startBroadcast();

        // Deploy the proxy vault contract
        address proxyVaultAddr = Upgrades.deployTransparentProxy(
            "Vault.sol",
            msg.sender,
            abi.encodeCall(Vault.initialize, (msg.sender, address(0x00)))
        );
        address implVaultAddr = Upgrades.getImplementationAddress(
            proxyVaultAddr
        );
        address adminVaultAddr = Upgrades.getAdminAddress(
            proxyVaultAddr
        );

        vm.stopBroadcast();

        return (proxyVaultAddr, implVaultAddr, adminVaultAddr);
    }

    function deployTssVerifier() internal returns (TssVerifier) {
        uint64 transitionPeriod = uint64(vm.envUint("TRANSITION_PERIOD"));
        bytes32 transitionOriginatorHash = bytes32(
            vm.envUint("TRANSITION_ORIGINATOR_HASH")
        );
        uint8 tssParity = uint8(vm.envUint("TSS_PARITY"));
        uint256 tssPublicKey = vm.envUint("TSS_PUBLIC_KEY");

        require(transitionPeriod != 0, "TRANSITION_PERIOD is not set");
        require(
            transitionOriginatorHash != bytes32(0),
            "TRANSITION_ORIGINATOR_HASH is not set"
        );
        require(tssParity != 0, "TSS_PARITY is not set");
        require(tssPublicKey != 0, "TSS_PUBLIC_KEY is not set");
        
        vm.startBroadcast();

        // Deploy the TssVerifier contract
        TssVerifier tssVerifier = new TssVerifier(
            transitionPeriod,
            transitionOriginatorHash,
            msg.sender
        );

         // Adding TSS public key to TssVerifier
        tssVerifier.addPubKeyByOwner(0, tssParity, tssPublicKey);


        vm.stopBroadcast();

        return tssVerifier;
    }

    function deployPriorityFeeTunnelRouter(TssVerifier tssVerifier, address proxyVaultAddr) internal returns (address, address, address) {
        uint256 priorityFee = vm.envUint("PRIORITY_FEE");
        string memory sourceChainId = vm.envString("SOURCE_CHAIN_ID");
        string memory targetChainId = vm.envString("TARGET_CHAIN_ID");
        bool refundable = vm.envOr("REFUNDABLE", true);

        require(
            keccak256(bytes(sourceChainId)) != keccak256(""),
            "SOURCE_CHAIN_ID is not set"
        );
        require(
            keccak256(bytes(targetChainId)) != keccak256(""),
            "TARGET_CHAIN_ID is not set"
        );

        vm.startBroadcast();

        // Deploy the proxy TunnelRouter contract
        address proxyPriorityFeeTunnelRouterAddr = Upgrades.deployTransparentProxy(
            "PriorityFeeTunnelRouter.sol",
            msg.sender,
            abi.encodeCall(
                PriorityFeeTunnelRouter.initialize,
                (
                    tssVerifier,
                    IVault(proxyVaultAddr),
                    17369806436495577561272982365083344973322337688717046180703435,
                    4000,
                    300000,
                    priorityFee,
                    keccak256(bytes(sourceChainId)),
                    keccak256(bytes(targetChainId)),
                    refundable
                )
            )
        );
        address implPriorityFeeTunnelRouterAddr = Upgrades.getImplementationAddress(
            proxyPriorityFeeTunnelRouterAddr
        );

        address adminPriorityFeeTunnelRouterAddr = Upgrades.getAdminAddress(
            proxyPriorityFeeTunnelRouterAddr
        );

        vm.stopBroadcast();

        return (proxyPriorityFeeTunnelRouterAddr, implPriorityFeeTunnelRouterAddr, adminPriorityFeeTunnelRouterAddr);
    }

    function deployGasPriceTunnelRouter(TssVerifier tssVerifier, address proxyVaultAddr) internal returns (address, address, address) {
        uint256 gasPrice = vm.envUint("GAS_PRICE");
        string memory sourceChainId = vm.envString("SOURCE_CHAIN_ID");
        string memory targetChainId = vm.envString("TARGET_CHAIN_ID");
        bool refundable = vm.envOr("REFUNDABLE", true);

        require(
            keccak256(bytes(sourceChainId)) != keccak256(""),
            "SOURCE_CHAIN_ID is not set"
        );
        require(
            keccak256(bytes(targetChainId)) != keccak256(""),
            "TARGET_CHAIN_ID is not set"
        );

        vm.startBroadcast();

        // Deploy the proxy TunnelRouter contract
        address proxyGasPriceTunnelRouterAddr = Upgrades.deployTransparentProxy(
            "GasPriceTunnelRouter.sol",
            msg.sender,
            abi.encodeCall(
                GasPriceTunnelRouter.initialize,
                (
                    tssVerifier,
                    IVault(proxyVaultAddr),
                    17369806436495577561272982365083344973322337688717046180703435,
                    4000,
                    300000,
                    gasPrice,
                    keccak256(bytes(sourceChainId)),
                    keccak256(bytes(targetChainId)),
                    refundable
                )
            )
        );
        address implGasPriceTunnelRouterAddr = Upgrades.getImplementationAddress(
            proxyGasPriceTunnelRouterAddr
        );

        address adminGasPriceTunnelRouterAddr = Upgrades.getAdminAddress(
            proxyGasPriceTunnelRouterAddr
        );

        vm.stopBroadcast();

        return (proxyGasPriceTunnelRouterAddr, implGasPriceTunnelRouterAddr, adminGasPriceTunnelRouterAddr);
    }
}
