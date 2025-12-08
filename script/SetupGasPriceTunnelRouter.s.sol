// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/upgrades.sol";

import {IVault} from "../src/interfaces/IVault.sol";
import {ITssVerifier} from "../src/interfaces/ITssVerifier.sol";

import {GasPriceTunnelRouter} from "../src/router/GasPriceTunnelRouter.sol";
import {TssVerifier} from "../src/TssVerifier.sol";
import {Vault} from "../src/Vault.sol";

contract Executor is Script {
    function run() external {
        uint64 transitionPeriod = uint64(vm.envUint("TRANSITION_PERIOD"));
        bytes32 transitionOriginatorHash = bytes32(
            vm.envUint("TRANSITION_ORIGINATOR_HASH")
        );
    uint256 gasPrice = vm.envUint("GAS_PRICE");
        string memory sourceChainId = vm.envString("SOURCE_CHAIN_ID");
        string memory targetChainId = vm.envString("TARGET_CHAIN_ID");

        require(transitionPeriod != 0, "TRANSITION_PERIOD is not set");
        require(
            transitionOriginatorHash != bytes32(0),
            "TRANSITION_ORIGINATOR_HASH is not set"
        );
        require(
            keccak256(bytes(sourceChainId)) != keccak256(""),
            "SOURCE_CHAIN_ID is not set"
        );
        require(
            keccak256(bytes(targetChainId)) != keccak256(""),
            "TARGET_CHAIN_ID is not set"
        );

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

        // Deploy the TssVerifier contract
        TssVerifier tssVerifier = new TssVerifier(
            transitionPeriod,
            transitionOriginatorHash,
            msg.sender
        );

        // Deploy the proxy TunnelRouter contract
        address proxyTunnelRouterAddr = Upgrades.deployTransparentProxy(
            "GasPriceTunnelRouter.sol",
            msg.sender,
            abi.encodeCall(
                GasPriceTunnelRouter.initialize,
                (
                    tssVerifier,
                    IVault(proxyVaultAddr),
                    msg.sender,
                    17369806436495577561272982365083344973315337688717046180703435,
                    4000,
                    300000,
                    gasPrice,
                    keccak256(bytes(sourceChainId)),
                    keccak256(bytes(targetChainId))
                )
            )
        );
        address implTunnelRouterAddr = Upgrades.getImplementationAddress(
            proxyTunnelRouterAddr
        );

        // Set the tunnel router address in the vault
        Vault(payable(proxyVaultAddr)).setTunnelRouter(proxyTunnelRouterAddr);

        vm.stopBroadcast();

        console.log("Vault Proxy deployed at:", proxyVaultAddr);
        console.log("Vault Implementation deployed at:", implVaultAddr);
        console.log("TssVerifier deployed at:", address(tssVerifier));
        console.log(
            "GasPriceTunnelRouter Proxy deployed at:",
            proxyTunnelRouterAddr
        );
        console.log(
            "GasPriceTunnelRouter Implementation deployed at:",
            implTunnelRouterAddr
        );
    }
}
